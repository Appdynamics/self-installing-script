--[[
 * Copyright (c) AppDynamics, Inc., and its affiliates
 * 2015
 * All Rights Reserved
 * THIS IS UNPUBLISHED PROPRIETARY CODE OF APPDYNAMICS, INC.
 * The copyright notice above does not evidence any actual or intended
 * publication of such source code
--]]

--
-- Metric types definition. This defines which type of value gets reported.
--
metric_type = {
	mt_avg = "Average",
	mt_agg = "Accumulate",
	mt_curr = "Current",
}

--
-- DMM mode definition.
--
dmm_mode = {
	dmm_kpi = "Kpi",
	dmm_diag = "Diagnostic",
	dmm_adv = "Advanced",
}

--
-- Time rollup types. Derived from kv.h
--
time_rollup = {
	tr_avg = 1,
	tr_sum = 2,
	tr_curr = 3,
}

--
-- Cluster rollup types. Derived from kv.h
--
cluster_rollup = {
	cr_indv = 1,
	cr_coll = 2,
}

--
-- Aggregation rollup types. Derived from kv.h
--
agg_rollup = {
	ar_avg = 1,
	ar_advavg = 2,
	ar_sum = 3,
	ar_curr = 4,
	ar_currinc = 5,
	ar_percentile = 6
}
