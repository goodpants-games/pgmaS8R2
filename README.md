# pgma s8r2 game
level sizes must be multiples of:
- X: 15
- Y: 11

map collision types:
| id | name  |
|----|-------|
| 0  | air   |
| 1  | solid |
| 2  | water |

## preprocessing
prerequisites:
- Python
- Tiled
- Aseprite (optional (maybe?))

auto-export tiled and aseprite assets
```bash
# windows default: C:\Program Files\Tiled\tiled.exe
# linux default: tiled
export TILED=<insert path to tiled.exe>
# default: aseprite
export ASEPRITE=<insert path to aseprite.exe>

python3 tools/assetexport.py
```

build pico-8 palette reducer reference image (only need to be done once, or when you change the algorithm or palette)
```bash
love root --debug --preproc-force
```