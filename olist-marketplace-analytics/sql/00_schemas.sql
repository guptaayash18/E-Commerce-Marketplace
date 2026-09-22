-- Three-layer layout: raw (as-loaded text), staging (typed + cleaned), mart (star schema).
-- Keeping the layers separate means every cleaning decision is visible as a diff
-- between raw and staging, and the mart can be rebuilt from staging at any time.
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS mart;
