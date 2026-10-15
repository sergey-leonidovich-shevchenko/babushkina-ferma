# Native baseline summary

Fixed native render target + host composite. Shared OPT quantiles; no GPU/route acceptance claim.

| Target | Mode | Location | Repeat | p95 ms | p99 ms | Max ms | Terrain rebuilds |
|---|---|---|---:|---:|---:|---:|---:|
| 1152x648 | normal | overworld | 0 | 15.68 | 16.631 | 16.787 | 0 |
| 1152x648 | normal | overworld | 1 | 14.938 | 15.825 | 16.728 | 0 |
| 1152x648 | normal | overworld | 2 | 15.526 | 16.628 | 33.388 | 0 |
| 1152x648 | normal | village_river | 0 | 10.443 | 14.12 | 15.353 | 0 |
| 1152x648 | normal | village_river | 1 | 10.312 | 10.765 | 11.769 | 0 |
| 1152x648 | normal | village_river | 2 | 10.382 | 10.671 | 11.236 | 0 |
| 1152x648 | normal | cave_lake | 0 | 14.149 | 15.091 | 15.217 | 0 |
| 1152x648 | normal | cave_lake | 1 | 11.74 | 13.6 | 13.89 | 0 |
| 1152x648 | normal | cave_lake | 2 | 10.827 | 13.125 | 14.391 | 0 |
| 1152x648 | normal | moon_glade | 0 | 15.137 | 15.225 | 15.464 | 0 |
| 1152x648 | normal | moon_glade | 1 | 15.152 | 15.281 | 15.472 | 0 |
| 1152x648 | normal | moon_glade | 2 | 15.177 | 15.296 | 15.515 | 0 |
| 1152x648 | normal | pirate_ship | 0 | 11.12 | 12.063 | 12.916 | 0 |
| 1152x648 | normal | pirate_ship | 1 | 10.595 | 10.854 | 11.037 | 0 |
| 1152x648 | normal | pirate_ship | 2 | 10.726 | 11.031 | 12.195 | 0 |
| 1920x1080 | normal | overworld | 0 | 34.888 | 35.61 | 36.803 | 0 |
| 1920x1080 | normal | overworld | 1 | 32.7 | 33.99 | 34.332 | 0 |
| 1920x1080 | normal | overworld | 2 | 25.635 | 31.876 | 32.571 | 0 |
| 1920x1080 | normal | village_river | 0 | 10.545 | 11.312 | 12.565 | 0 |
| 1920x1080 | normal | village_river | 1 | 10.233 | 10.563 | 11.155 | 0 |
| 1920x1080 | normal | village_river | 2 | 10.495 | 10.761 | 10.923 | 0 |
| 1920x1080 | normal | cave_lake | 0 | 13.887 | 14.851 | 16.199 | 0 |
| 1920x1080 | normal | cave_lake | 1 | 13.742 | 15.527 | 16.198 | 0 |
| 1920x1080 | normal | cave_lake | 2 | 13.896 | 15.358 | 15.719 | 0 |
| 1920x1080 | normal | moon_glade | 0 | 14.335 | 15.097 | 16.14 | 0 |
| 1920x1080 | normal | moon_glade | 1 | 14.597 | 15.259 | 15.994 | 0 |
| 1920x1080 | normal | moon_glade | 2 | 14.024 | 14.397 | 15.3 | 0 |
| 1920x1080 | normal | pirate_ship | 0 | 14.218 | 16.128 | 19.222 | 0 |
| 1920x1080 | normal | pirate_ship | 1 | 10.578 | 10.955 | 11.194 | 0 |
| 1920x1080 | normal | pirate_ship | 2 | 10.771 | 11.129 | 11.327 | 0 |
| 3584x2016 | normal | overworld | 0 | 15.391 | 17.044 | 31.249 | 0 |
| 3584x2016 | normal | overworld | 1 | 17.176 | 26.843 | 31.586 | 0 |
| 3584x2016 | normal | overworld | 2 | 19.13 | 23.873 | 31.368 | 0 |
| 3584x2016 | normal | village_river | 0 | 14.509 | 14.922 | 15.976 | 0 |
| 3584x2016 | normal | village_river | 1 | 15.605 | 16.193 | 25.414 | 0 |
| 3584x2016 | normal | village_river | 2 | 15.26 | 15.822 | 25.051 | 0 |
| 3584x2016 | normal | cave_lake | 0 | 14.489 | 14.991 | 15.724 | 0 |
| 3584x2016 | normal | cave_lake | 1 | 14.839 | 15.666 | 15.826 | 0 |
| 3584x2016 | normal | cave_lake | 2 | 14.278 | 15.25 | 15.396 | 0 |
| 3584x2016 | normal | moon_glade | 0 | 16.689 | 24.803 | 25.196 | 0 |
| 3584x2016 | normal | moon_glade | 1 | 10.519 | 12.508 | 16.027 | 0 |
| 3584x2016 | normal | moon_glade | 2 | 10.334 | 10.558 | 10.6 | 0 |
| 3584x2016 | normal | pirate_ship | 0 | 13.832 | 14.866 | 19.077 | 0 |
| 3584x2016 | normal | pirate_ship | 1 | 11.378 | 11.691 | 11.948 | 0 |
| 3584x2016 | normal | pirate_ship | 2 | 10.875 | 11.123 | 11.765 | 0 |
| 1152x648 | F10 | overworld | 0 | 21.508 | 29.295 | 33.541 | 0 |
| 1152x648 | F10 | overworld | 1 | 30.421 | 32.798 | 35.556 | 0 |
| 1152x648 | F10 | overworld | 2 | 44.71 | 57.192 | 58.175 | 0 |

Raw data: [normal 1152](before/native-1152.json), [normal 1920](before/native-1920.json), [normal 3584](before/native-3584.json), [F10](before-f10/native-1152.json).
