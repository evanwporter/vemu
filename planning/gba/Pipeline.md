
The basic pipeline is as follows:

| Cycle | 1   | 2   | 3   | 4   | 5   | 6   |
| ----- | --- | --- | --- | --- | --- | --- |
| I1    | F   | D   | I   | E   |     |     |
| I2    |     | F   | -   | D   | E   |     |
| I3    |     |     |     | F   | D   | E   |

The fetch done in `Cycle 2` can happen at any point before the final execution. So it could've also happened in `Cycle 3`.

Changing the value of `PC` causes the pipeline to be flushed:

| Cycle   | 1   | 2   | 3   | 4   | 5   | 6   | 7   | 8   |
| ------- | --- | --- | --- | --- | --- | --- | --- | --- |
| I1      | F   | D   | E   |     |     |     |     |     |
| Discard |     | F   | D   |     |     |     |     |     |
| Discard |     |     | F   |     |     |     |     |     |
| I2      |     |     |     | F   | D   | E   |     |     |
| I3      |     |     |     |     | F   | D   | E   |     |
| I4      |     |     |     |     |     | F   | D   | E   |
