# Web build output

Run `tools/export_web.sh` to generate these Godot Web files here:

- `index.html`
- `index.js`
- `index.wasm`
- `index.pck`

Then serve them with:

```bash
python3 tools/serve_web.py --directory web-build --port 8000
```
