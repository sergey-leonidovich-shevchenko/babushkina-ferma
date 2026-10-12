"""Validate full native scenarios using frame_post_draw, not idle process loops."""
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
REPORTS=ROOT/"docs/reports/performance-2026-10-12/final4"


def main():
    checked=0
    for window in ("window","fullscreen"):
        for scenario in ("boss","profile_town"):
            for mode in ("normal","f10"):
                path=REPORTS/window/("native_"+scenario+"_"+mode+".json")
                data=json.loads(path.read_text())
                frames=data["draw_intervals_ms"]
                assert len(frames)>=1000 and all(math.isfinite(x) and x>0 for x in frames),path
                ordered=sorted(frames)
                p95=ordered[int((len(ordered)-1)*.95)]
                assert abs(p95-data["draw_frame"]["p95_ms"])<.0001,path
                assert p95<=20.0,(path,p95)
                assert data["mode"]==mode and data["user_saves_unchanged"],path
                assert data["window_mode"]==(3 if window=="fullscreen" else 0),path
                assert data["pacing_policy"]=="demand_0.5ms",path
                if scenario=="boss":
                    assert data["simulation_seconds"]>=25 and data["peak_minions"]==4 and data["peak_projectiles"]>=25,path
                    assert set(data["attacks"])=={"cross","spiral","triple_charge","pulse"},path
                else:
                    assert data["route_finished"] and data["town_loops"]>=1,path
                print(window,scenario,mode,"draw p95",p95)
                checked+=1
    print("NATIVE FRAME REPORTS:",checked,"full scenarios passed")


if __name__=="__main__":
    main()
