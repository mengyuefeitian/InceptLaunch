# Full-resolution icon sources (not packaged)

These PNG files are master artwork used by `script/optimize_icons.sh` to rebuild
compact `.icns` files. They are **not** copied into `InceptLaunch.app`.

Runtime shipping assets (in the app bundle):

- `Resources/Icons/*.icns` — Dock / app icon variants
- `Resources/Icons/thumb_*.png` — settings picker thumbnails (~20KB each)

Regenerate optimized icns after editing a source PNG:

```bash
bash script/optimize_icons.sh
bash script/build_and_run.sh --verify
```
