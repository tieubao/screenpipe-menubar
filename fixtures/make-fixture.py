#!/usr/bin/env python3
"""Build a tiny screenpipe-shaped sqlite fixture for testing scrub-elements.py.

Creates an `elements` table (id, text) + the `elements_au` UPDATE trigger + an
`elements_fts` mirror, matching the columns scrub-elements.py touches. Rows mix
clean text with synthetic secrets assembled from parts (so no real credential
literal lives in this repo). Run: python3 fixtures/make-fixture.py [out.sqlite]
"""
import sqlite3
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "fixtures/elements-fixture.sqlite"

# Secrets assembled from parts so the repo carries no literal credential.
aws = "AKIA" + "ABCDEFGHIJKLMNOP"
gh = "ghp_" + "A" * 36
env = "API_KEY=" + "x7Kf9Lm2Qp8Rt4Vw0Yz"
seed = " ".join(["abandon"] * 12)  # 12 BIP-39 words -> seed-phrase shape

rows = [
    "Inbox (3) - Mail",                         # clean
    "def handler(req): return 200",             # clean
    f"export {env}",                             # env-assignment secret
    f"aws_access_key_id = {aws}",                # provider regex
    f"git remote add origin https://x:{gh}@github.com/o/r",  # github token
    f"recovery words: {seed}",                   # BIP-39 seed
    "https://example.com/page?ref=home",         # clean (no token param)
]

con = sqlite3.connect(OUT)
cur = con.cursor()
cur.executescript("""
DROP TABLE IF EXISTS elements;
DROP TABLE IF EXISTS elements_fts;
CREATE TABLE elements (id INTEGER PRIMARY KEY, text TEXT);
CREATE VIRTUAL TABLE elements_fts USING fts5(text, content='elements', content_rowid='id');
CREATE TRIGGER elements_au AFTER UPDATE ON elements BEGIN
  INSERT INTO elements_fts(elements_fts, rowid, text) VALUES('delete', old.id, old.text);
  INSERT INTO elements_fts(rowid, text) VALUES (new.id, new.text);
END;
""")
for i, t in enumerate(rows, 1):
    cur.execute("INSERT INTO elements (id, text) VALUES (?, ?)", (i, t))
    cur.execute("INSERT INTO elements_fts (rowid, text) VALUES (?, ?)", (i, t))
con.commit()
con.close()
print(f"wrote {OUT} with {len(rows)} rows "
      f"({sum(1 for r in rows if any(k in r for k in (aws, gh, env, seed)))} contain secrets)")
