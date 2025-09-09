Actions you should run locally in PowerShell from the repo root (C:\code\kingdom_working\kingdom):

1) Ensure you're on the branch you want to push:
   git status
   git branch --show-current

2) Stage only the functions lockfile and .gitignore:
   git add functions/.gitignore functions/package.json functions/package-lock.json

3) Commit the change:
   git commit -m "chore(functions): add .gitignore and update lockfile for Cloud Build" -- functions/.gitignore functions/package.json functions/package-lock.json

4) Push to origin:
   git push origin $(git branch --show-current)

5) Deploy the single function (replace project id if different):
   firebase deploy --only functions:grantPoints --project kingdom-ac44f --debug

Troubleshooting notes:
- If git refuses to commit because of local unstaged changes elsewhere, either stash them:
   git stash push -m "WIP: temporary" 
  then run steps 2..4 and later restore with `git stash pop`.

- If Cloud Build fails with EBADENGINE or lockfile mismatch, run `npm install` inside `functions/` locally, commit the updated package-lock.json, and retry deploy.
- If Cloud Build shows Artifact Registry or Compute Service Account errors, you'll need to enable Compute Engine API in GCP and grant the Cloud Functions service account the `roles/artifactregistry.reader` permission via the Cloud Console or gcloud.

Safety:
- Do NOT commit any service account JSON or secrets. If present, add them to .gitignore and remove from git with:
   git rm --cached path/to/key.json

After running the steps above, paste the `firebase deploy` output here and I will analyze the Cloud Build logs and recommend fixes.
