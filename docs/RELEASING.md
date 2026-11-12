# Releasing Sotto

Releases are automatic: pushing a version tag to GitHub runs `.github/workflows/release.yml`,
which runs the offline tests, packages the addon with the BigWigs packager (only the
addon files: `.pkgmeta` leaves out `docs/`, `tests/`, `tools/`, `README.md`, `CLAUDE.md`)
and uploads it. A GitHub release with the zip is always created; CurseForge, Wago and
WoWInterface get the file once their project id and token are set up (below).

## One-time setup

### 1. Create the CurseForge project (in the browser, your account)

1. Go to https://authors.curseforge.com, choose **Create Project**, game **World of
   Warcraft**, class **Addons**.
2. Fill in the form from [listing/curseforge.md](listing/curseforge.md): name, summary,
   description, category **Chat & Communication**, license **MIT**, avatar
   `listing/icon-400.png`.
3. Submit. CurseForge reviews new projects; once it is created, note the **Project ID**
   (shown on the project's About box).

### 2. Put the project id into the TOC

Add this line to `Sotto.toc` (under `## Author`) and commit it:

```
## X-Curse-Project-ID: 123456
```

### 3. Give GitHub an upload token

1. CurseForge: https://authors.curseforge.com/account/api-tokens → create a token.
2. GitHub: repository **Settings → Secrets and variables → Actions → New repository
   secret**, name `CF_API_KEY`, value the token.

Optional, the same way: Wago (`## X-Wago-ID` + secret `WAGO_API_TOKEN`), WoWInterface
(`## X-WoWI-ID` + secret `WOWI_API_TOKEN`).

### 4. Gallery

Upload `listing/screenshots/01…06` to the project's gallery with the captions from
[listing/curseforge.md](listing/curseforge.md). The packager does not touch images.

## Every release

1. Add the changes under a new version heading in `CHANGELOG.md` (the packager uses it as
   the file's changelog) and commit.
2. Tag and push:

   ```sh
   git tag 1.0.0
   git push origin main 1.0.0
   ```

   `1.0.0` uploads a release file; `1.1.0-beta1` a beta, `1.1.0-alpha1` an alpha.
   `## Version: @project-version@` in the TOC becomes the tag.
3. Watch the run under the repository's **Actions** tab. It fails before uploading if a
   test fails.

## Notes

- The repository is private for now. CurseForge does not need it to be public.
- Commits use the repository's own identity (`creazy231`, GitHub no-reply address);
  keep it that way (`git config user.name`, `user.email` in this repository).
- `docs/mockup/` (the design mockup with a private game screenshot and EllesmereUI's
  licensed font) is ignored by git; never add it.
