const bcrypt = require("bcryptjs");
const { db, init } = require("./db");

function seed() {
    init();

    // Wipe any existing data (idempotent fresh seed)
    db.exec(`
        DELETE FROM reports;
        DELETE FROM projects;
        DELETE FROM users;
        DELETE FROM orgs;
        DELETE FROM sqlite_sequence WHERE name IN ('reports','projects','users','orgs');
    `);

    const pw = bcrypt.hashSync("password123", 10);

    const insertOrg = db.prepare(
        "INSERT INTO orgs (slug, name) VALUES (?, ?)"
    );
    const pithId = insertOrg.run("pith", "Pith").lastInsertRowid;
    const marrowId = insertOrg.run("marrow", "Marrow").lastInsertRowid;

    const insertUser = db.prepare(
        "INSERT INTO users (org_id, email, name, password_hash, role) VALUES (?, ?, ?, ?, ?)"
    );
    insertUser.run(pithId, "alice@pith.co", "Alice Chen", pw, "admin");
    insertUser.run(pithId, "mallory@pith.co", "Mallory Smith", pw, "member");
    insertUser.run(marrowId, "bob@marrow.co", "Bob Reyes", pw, "admin");
    insertUser.run(marrowId, "carol@marrow.co", "Carol Okafor", pw, "member");

    const insertProject = db.prepare(
        "INSERT INTO projects (org_id, name, description) VALUES (?, ?, ?)"
    );
    const pithPlanning = insertProject.run(
        pithId,
        "2026 Operating Plan",
        "Company-wide planning for fiscal year 2026."
    ).lastInsertRowid;
    const pithHR = insertProject.run(
        pithId,
        "People Ops",
        "Compensation reviews, hiring plans, and HR initiatives."
    ).lastInsertRowid;
    const marrowMA = insertProject.run(
        marrowId,
        "Project Horizon",
        "Strategic initiatives \u2014 restricted visibility."
    ).lastInsertRowid;
    const marrowSales = insertProject.run(
        marrowId,
        "Customer Accounts",
        "Enterprise customer portfolio and renewal tracking."
    ).lastInsertRowid;

    const insertReport = db.prepare(
        "INSERT INTO reports (project_id, title, body, sensitivity) VALUES (?, ?, ?, ?)"
    );

    // Pith reports.
    insertReport.run(
        pithPlanning,
        "Q1 Revenue Summary",
        "Revenue tracking to plan. Numbers approximate pending close.\nSee finance drive for reconciled figures.",
        "normal"
    );
    insertReport.run(
        pithHR,
        "2026 Salary Review \u2014 Engineering",
        "Confidential band adjustments for FY26.\n\n" +
            "| Role        | Current Band | New Band |\n" +
            "|-------------|--------------|----------|\n" +
            "| IC3         | 145\u2013175k    | 160\u2013190k |\n" +
            "| IC4         | 175\u2013210k    | 195\u2013235k |\n" +
            "| IC5         | 210\u2013260k    | 240\u2013295k |\n" +
            "| Staff       | 260\u2013325k    | 295\u2013365k |\n",
        "confidential"
    );

    // Marrow reports.
    insertReport.run(
        marrowMA,
        "Horizon \u2014 Acquisition Terms Sheet",
        "DRAFT \u2014 not for distribution outside deal team.\n\n" +
            "Target: Arven Systems, Inc.\n" +
            "Offer: $420M, 60% stock / 40% cash\n" +
            "Expected close: Q3 2026\n" +
            "Key retention grants: 4-year vest, 1-year cliff\n" +
            "Walk-away price: $385M",
        "confidential"
    );
    insertReport.run(
        marrowSales,
        "Top 50 Customer Export",
        "ACCOUNT,ARR,RENEWAL,OWNER\n" +
            "Perrin Industrial,$2.4M,2026-08-15,B. Reyes\n" +
            "Astor Mutual,$1.9M,2026-06-30,C. Okafor\n" +
            "Keyline Logistics,$1.6M,2027-01-12,B. Reyes\n" +
            "Garrigan Retail Group,$1.4M,2026-11-04,C. Okafor\n" +
            "Varda Foods,$1.2M,2026-07-22,B. Reyes\n" +
            "\u2014 additional 45 accounts elided \u2014\n",
        "confidential"
    );

    console.log("Seeded.");
    console.log(`  Orgs: Pith (id=${pithId}), Marrow (id=${marrowId})`);
}

if (require.main === module) {
    seed();
}

module.exports = { seed };
