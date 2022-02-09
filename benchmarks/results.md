# Benchmark Results

## System

all Benchmarks are run on

```
Operating System: macOS
CPU Information: Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz
Number of Available Cores: 12
Available memory: 16 GB
Elixir 1.13.2
Erlang 24.1.5
```

## Results

### Initial

1. Check for missing options/rules for given status
2. Check for ignored value
3. Build the EntityStatus if necessary
4. Modify TrackingData

| Name                  |    ips | average |  deviation | median |  99th % |
|-----------------------|-------:|--------:|-----------:|-------:|--------:|
| option_does_not_exist |  4.91 M| 0.20 μs |  ±11551%   |    0 μs|  0.98 μs|
| ignored_value         |  2.96 M| 0.34 μs |  ±11493%   |    0 μs|  0.98 μs|
| used_value            |  0.42 M| 2.39 μs |    ±711%   | 1.98 μs|  3.98 μs|
| creating_new_entity   | 0.179 M| 5.57 μs |    ±353%   | 4.98 μs| 23.98 μs|

### Add: Create TrackingData for given option to EntityStatus if missing

| Name                  |    ips | average |  deviation | median |  99th % |
|-----------------------|-------:|--------:|-----------:|-------:|--------:|
| option_does_not_exist | 4.83 M | 0.21 μs | ±11466%    |   0 μs |    1 μs |
| ignored_value         | 3.55 M | 0.28 μs |  ±7384%    |   0 μs |    1 μs |
| used_value            | 0.41 M | 2.43 μs |  ±1023%    |   2 μs |    4 μs |
| creating_new_entity   | 0.19 M | 5.23 μs |   ±414%    |   4 μs |   19 μs |

### Add: Transitions update the current_status value in EntityStatus

| Name                  |    ips | average |  deviation | median |  99th % |
|-----------------------|-------:|--------:|-----------:|-------:|--------:|
| option_does_not_exist | 4.91 M | 0.20 μs | ±10856%    | 0 μs   |   1 μs  |
| ignored_value         | 3.47 M | 0.29 μs |  ±6927%    | 0 μs   |   1 μs  |
| used_value            | 0.48 M | 2.08 μs |  ±1644%    | 2 μs   |   3 μs  |
| creating_new_entity   | 0.20 M | 5.05 μs |   ±418%    | 4 μs   |  18 μs  |
