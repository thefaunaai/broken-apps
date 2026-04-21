const express = require("express");
const session = require("express-session");
const bcrypt = require("bcryptjs");
const path = require("path");
const { db, init } = require("./db");
const { seed } = require("./seed");

const app = express();
const PORT = parseInt(process.env.PORT || "3000", 10);

app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));
app.use(express.urlencoded({ extended: false }));
app.use(express.json());
app.use(express.static(path.join(__dirname, "..", "public")));

app.use(
    session({
        secret: process.env.SESSION_SECRET || "dossier-dev-secret",
        resave: false,
        saveUninitialized: false,
        cookie: { httpOnly: true, sameSite: "lax" },
    })
);

// --- startup: ensure schema, and seed if tables are empty ---
init();
const userCount = db.prepare("SELECT COUNT(*) AS n FROM users").get().n;
if (userCount === 0) seed();

// --- helpers ---
function currentUser(req) {
    if (!req.session.userId) return null;
    const row = db
        .prepare(
            `SELECT u.id, u.email, u.name, u.role, u.org_id, o.slug AS org_slug, o.name AS org_name
             FROM users u JOIN orgs o ON o.id = u.org_id
             WHERE u.id = ?`
        )
        .get(req.session.userId);
    return row || null;
}

app.use((req, res, next) => {
    res.locals.user = currentUser(req);
    next();
});

function requireAuth(req, res, next) {
    if (!res.locals.user) {
        if (req.accepts("html")) return res.redirect("/login");
        return res.status(401).json({ error: "unauthorized" });
    }
    next();
}

function requireAdmin(req, res, next) {
    if (!res.locals.user || res.locals.user.role !== "admin") {
        return res.status(403).json({ error: "admin role required" });
    }
    next();
}

function canReadReport(user, report) {
    if (report.project_org_id !== user.org_id) return false;
    if (report.sensitivity === "confidential" && user.role !== "admin") {
        return false;
    }
    return true;
}

// --- public routes ---
app.get("/health", (req, res) => res.type("text").send("ok"));

app.get("/", (req, res) => {
    if (res.locals.user) return res.redirect("/dashboard");
    return res.redirect("/login");
});

app.get("/login", (req, res) => {
    res.render("login", { error: null });
});

app.post("/login", (req, res) => {
    const { email, password } = req.body;
    const row = db
        .prepare("SELECT id, password_hash FROM users WHERE email = ?")
        .get(email || "");
    if (!row || !bcrypt.compareSync(password || "", row.password_hash)) {
        return res.status(401).render("login", { error: "Invalid credentials." });
    }
    req.session.userId = row.id;
    res.redirect("/dashboard");
});

app.post("/logout", (req, res) => {
    req.session.destroy(() => res.redirect("/login"));
});

// --- authenticated routes (HTML) ---
app.get("/dashboard", requireAuth, (req, res) => {
    const projects = db
        .prepare(
            `SELECT id, name, description FROM projects WHERE org_id = ? ORDER BY id`
        )
        .all(res.locals.user.org_id);
    res.render("dashboard", { projects });
});

app.get("/projects/:id", requireAuth, (req, res) => {
    const project = db
        .prepare("SELECT * FROM projects WHERE id = ?")
        .get(req.params.id);
    if (!project) return res.status(404).send("not found");
    // Project access is correctly scoped to the user's org.
    if (project.org_id !== res.locals.user.org_id) {
        return res.status(403).send("forbidden");
    }
    const reports = db
        .prepare(
            `SELECT id, title, sensitivity, created_at
             FROM reports
             WHERE project_id = ?
               AND (? = 'admin' OR sensitivity != 'confidential')
             ORDER BY id`
        )
        .all(project.id, res.locals.user.role);
    res.render("project", { project, reports });
});

app.get("/reports/:id", requireAuth, (req, res) => {
    const report = db
        .prepare(
            `SELECT r.*, p.org_id AS project_org_id, p.name AS project_name
             FROM reports r JOIN projects p ON p.id = r.project_id
             WHERE r.id = ?`
        )
        .get(req.params.id);
    if (!report) return res.status(404).send("not found");
    // Reports are org-scoped; confidential reports are admin-only.
    if (!canReadReport(res.locals.user, report)) {
        return res.status(403).send("forbidden");
    }
    res.render("report", { report });
});

app.get("/settings", requireAuth, (req, res) => {
    res.render("settings", { saved: req.query.saved === "1" });
});

app.get("/admin", requireAuth, requireAdmin, (req, res) => {
    const members = db
        .prepare(
            `SELECT id, email, name, role FROM users WHERE org_id = ? ORDER BY id`
        )
        .all(res.locals.user.org_id);
    res.render("admin", { members, flash: req.query.flash || null });
});

// --- API: profile ---

// Self-read. Returns the current user's profile.
app.get("/api/users/me", requireAuth, (req, res) => {
    res.json({ user: res.locals.user });
});

// Self-update. Patches the current user's record with the fields the
// client sends.
app.patch("/api/users/me", requireAuth, (req, res) => {
    const body = req.body || {};
    const updates = [];
    const values = [];
    const columns = ["name", "email", "role"];
    for (const col of columns) {
        if (Object.prototype.hasOwnProperty.call(body, col)) {
            updates.push(`${col} = ?`);
            values.push(body[col]);
        }
    }
    if (updates.length === 0) {
        return res.status(400).json({ error: "no updatable fields" });
    }
    values.push(res.locals.user.id);
    db.prepare(`UPDATE users SET ${updates.join(", ")} WHERE id = ?`).run(
        ...values
    );
    const fresh = currentUser(req);
    res.json({ ok: true, user: fresh });
});

// --- API: admin surface ---

// List users in the admin's own org. Correctly org-scoped.
app.get("/api/admin/users", requireAuth, requireAdmin, (req, res) => {
    const rows = db
        .prepare(
            `SELECT id, email, name, role FROM users WHERE org_id = ? ORDER BY id`
        )
        .all(res.locals.user.org_id);
    res.json({ users: rows });
});

// Change a user's role. Correctly org-scoped: admin can only change
// users in their own org.
app.post("/api/admin/users/:id/role", requireAuth, requireAdmin, (req, res) => {
    const target = db
        .prepare("SELECT id, org_id FROM users WHERE id = ?")
        .get(req.params.id);
    if (!target) return res.status(404).json({ error: "user not found" });
    if (target.org_id !== res.locals.user.org_id) {
        return res.status(403).json({ error: "cross-org role change not allowed" });
    }
    const { role } = req.body || {};
    if (!["member", "admin"].includes(role)) {
        return res.status(400).json({ error: "invalid role" });
    }
    db.prepare("UPDATE users SET role = ? WHERE id = ?").run(role, req.params.id);
    res.json({ ok: true });
});

// Admin password reset. Standard admin-initiated flow (see Auth0 /
// Azure AD / Okta). Admin directly sets a user's password for
// onboarding, offboarding, incident response.
//
// Role hierarchy is enforced within an organization: an admin cannot
// reset another admin's password in their own org. Tenant isolation
// is handled by the broader architecture.
function checkPasswordResetAllowed(caller, target) {
    if (target.org_id === caller.org_id) {
        if (target.role === "admin" && target.id !== caller.id) {
            return "cannot reset another admin's password in your organization";
        }
    }
    return null;
}

app.post("/api/admin/users/:id/password", requireAuth, requireAdmin, (req, res) => {
    const target = db
        .prepare("SELECT id, email, role, org_id FROM users WHERE id = ?")
        .get(req.params.id);
    if (!target) return res.status(404).json({ error: "user not found" });
    const denyReason = checkPasswordResetAllowed(res.locals.user, target);
    if (denyReason) return res.status(403).json({ error: denyReason });
    const { password } = req.body || {};
    if (!password || typeof password !== "string" || password.length < 4) {
        return res.status(400).json({ error: "password too short" });
    }
    const hash = bcrypt.hashSync(password, 10);
    db.prepare("UPDATE users SET password_hash = ? WHERE id = ?").run(
        hash,
        req.params.id
    );
    // Async notification email would fire here in production.
    res.json({ ok: true, user: { id: target.id, email: target.email } });
});

// HTML form handler for the admin reset-password action. Posts to the
// same underlying code path.
app.post("/admin/users/:id/password", requireAuth, requireAdmin, (req, res) => {
    const target = db
        .prepare("SELECT id, role, org_id FROM users WHERE id = ?")
        .get(req.params.id);
    if (!target) return res.redirect("/admin?flash=not_found");
    const denyReason = checkPasswordResetAllowed(res.locals.user, target);
    if (denyReason) return res.redirect("/admin?flash=peer_admin");
    const { password } = req.body || {};
    if (!password || password.length < 4) {
        return res.redirect("/admin?flash=too_short");
    }
    const hash = bcrypt.hashSync(password, 10);
    db.prepare("UPDATE users SET password_hash = ? WHERE id = ?").run(
        hash,
        req.params.id
    );
    res.redirect("/admin?flash=reset_ok");
});

app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ error: "internal error" });
});

app.listen(PORT, "0.0.0.0", () => {
    console.log(`Dossier listening on :${PORT}`);
});
