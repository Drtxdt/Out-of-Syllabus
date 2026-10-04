"""Read actual UI save records; never change sessions or save files."""
import argparse
import hashlib
import json
import math
from pathlib import Path


def analyze(path):
    raw = Path(path).read_bytes()
    envelope = json.loads(raw)
    assert hashlib.sha256(envelope['payload'].encode()).hexdigest() == envelope['sha256']
    payload = json.loads(envelope['payload'])
    state = payload['state']
    events = state['events']
    choice = next(e for e in events if e['kind'] == 'choose_future')
    release = next(e for e in events if e['kind'] == 'gate_release')
    samples = [s for s in state['samples'] if choice['tick'] <= s['tick'] <= release['tick']]
    distance = sum(math.dist(a['position'], b['position']) for a, b in zip(samples, samples[1:]) if a['room'] == b['room'])
    return dict(save=str(Path(path).resolve()), sha256=hashlib.sha256(raw).hexdigest(),
                choice=state['finale']['choice'], completed=state['completed'],
                choice_tick=choice['tick'], gate_release_tick=release['tick'],
                pre_chase_world_ticks=release['tick']-choice['tick'],
                pre_chase_sampled_walk_px=round(distance, 3),
                sampled_rooms=list(dict.fromkeys(s['room'] for s in samples)),
                violations=state['finale']['violations'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--accept', required=True)
    parser.add_argument('--refuse', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    accept, refuse = analyze(args.accept), analyze(args.refuse)
    assert accept['completed'] and refuse['completed']
    assert accept['choice'] == 'accept' and refuse['choice'] == 'refuse'
    assert accept['pre_chase_sampled_walk_px'] < refuse['pre_chase_sampled_walk_px']
    report = dict(accept=accept, refuse=refuse,
                  saved_sampled_walk_px=round(refuse['pre_chase_sampled_walk_px']-accept['pre_chase_sampled_walk_px'], 3),
                  saved_world_ticks=refuse['pre_chase_world_ticks']-accept['pre_chase_world_ticks'],
                  method='Actual input route saves: choose_future through gate_release, before pursuit. Sum consecutive same-room position samples; room transitions excluded. Sampled distance is approximate. Fixed ticks exclude paused menus, not human duration.')
    Path(args.output).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(report, ensure_ascii=False, indent=2))
