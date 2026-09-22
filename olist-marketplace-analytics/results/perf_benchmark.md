# Performance benchmark

Median of 5 EXPLAIN (ANALYZE) runs, PostgreSQL execution time. Result-set check: naive and window queries return 98,207 identical rows.

| Query | With indexes | Without secondary indexes |
|---|---|---|
| A_naive_correlated_subquery | 980.1 ms | timed out (>90 s) |
| A_window_function | 204.3 ms | 220.8 ms |
| B_late_orders_march_2018 | 20.5 ms | 50.8 ms |

Rewrite speed-up (with indexes): 4.8x
Index speed-up on query B: 2.5x
