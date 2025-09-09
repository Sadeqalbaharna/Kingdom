Recommendation: migrate functions to Node 20 (Gen2 recommended)

Why:
- Node 18 reaches EOL sooner; many npm packages now require Node >=20.
- Cloud Functions Gen1 supports Node 18 only; to use Node 20 you must deploy to Cloud Functions Gen2 or select runtime nodejs20 if supported by your Firebase CLI/project.

Steps (preferred, sustainable):
1) Update `package.json` engines.node to "20" (already done).
2) Regenerate the lockfile locally with Node 20 installed:
   - Install Node 20 via nvm or installer
   - cd functions
   - npm ci || npm install
   - Commit updated package-lock.json
3) Deploy to Gen2 / Node 20:
   - Use `firebase deploy --only functions:grantPoints --project kingdom-ac44f --debug` after confirming your firebase/cli supports gen2 runtimes.
   - Alternatively, use `gcloud functions deploy grantPoints --region=us-central1 --runtime=nodejs20 --gen2 ...` if using gcloud.

Notes:
- If you cannot switch to Node 20 in the short term, pin firebase-admin and firebase-functions to versions compatible with Node 18 and regenerate the lockfile, then deploy.
- After a successful deploy, remove any debug fallback in the client and verify callable works from web.
