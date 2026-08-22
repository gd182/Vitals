import time, sys, multiprocessing

def worker(target, ramp_seconds=10):
    start = time.time()
    while True:
        elapsed = time.time() - start
        percent = min(target, (elapsed / ramp_seconds) * target)
        interval = 1 - percent / 100
        busy = time.time() + (percent / 100)
        while time.time() < busy:
            pass
        time.sleep(max(0, interval))

if __name__ == '__main__':
    target = int(sys.argv[1]) if len(sys.argv) > 1 else 50
    ramp = int(sys.argv[2]) if len(sys.argv) > 2 else 10

    procs = [multiprocessing.Process(target=worker, args=(target, ramp))
             for _ in range(multiprocessing.cpu_count())]
    for p in procs: p.start()
    for p in procs: p.join()
