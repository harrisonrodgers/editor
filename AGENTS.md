# Agents

This repo builds the container you are running in. The `Dockerfile` installs the tools, and the files under `home/`
become your `$HOME` (zsh, git, nvim, Claude Code config, ...). The repo is mounted at `/host`, and it is the only thing
that survives when the container stops (it is started with `--rm`). See `README.md` for the full layout.

## Make Every Change Twice

The live environment is a **copy** made at build time, not a link to the repo. So make each change in both places:

1. **The live environment**, so you can test it now (e.g. source the shell config, run the tool, open nvim).
2. **The repo under `/host`**, so it can be committed and is in the next image build.

A change made only in the repo can't be tested until the next rebuild. A change made only in the live environment is
lost when the container stops.

| repo (`/host/...`)   | live environment                                                             |
|----------------------|------------------------------------------------------------------------------|
| `home/<path>`        | `~/<path>`, e.g. `home/.config/zsh/.zshrc` -> `~/.config/zsh/.zshrc`         |
| `sandbox/conda/`     | `/sandbox/${USER}/conda/`                                                    |
| `Dockerfile` (nix)   | the nix profile: add a nixpkgs package live with `nix profile add nixpkgs#x` |
| `Dockerfile` (`ENV`) | needs a rebuild; for a quick test, `export` it in your shell                 |

After a change, check that the live file and the repo file match (e.g. `diff home/<path> ~/<path>`).

## Notes

- Keep `README.md` up to date when a change affects anything it documents.
- Don't commit or push unless asked.
