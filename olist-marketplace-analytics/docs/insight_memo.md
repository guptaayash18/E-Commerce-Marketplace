# Insight memo — Olist marketplace, Sep 2016 to Oct 2018

**To:** Head of Operations, Head of Seller Success
**From:** Analytics
**Basis:** 99,441 orders, 96,470 delivered with a delivery timestamp, R$13.22M delivered GMV, 96,096 buyers, 3,095 sellers. All figures from `sql/analysis/`, outputs in `results/`.

## 1. Late delivery is the single biggest driver of bad reviews

A parcel that arrives after the promised date gets a 1-star review 54.2% of the time; an on-time parcel gets one 6.8% of the time. That is a 7.9× difference, and it is dose-dependent: 1–3 days late lifts the 1-star share to 25.3%, 4–7 days to 59.1%, and 8–14 days to 70.6%. Average review falls from 4.28 to 2.26. (q02)

Overall only 6.77% of deliveries are late (6,534 orders), but the rate is not stable. March 2018 hit 18.96% on 7,003 deliveries, February 2018 14.13%, November 2017 (Black Friday) 12.40%. By destination, Alagoas (21.4%), Maranhão (17.4%) and Sergipe (15.2%) run at two to three times the network rate. (q01)

**Recommendation.** Treat the promised date as a product, not a logistics output. Two levers: (a) widen the promise for the North-East states and for November–March peak weeks, where the current promise is missed most; (b) put an explicit SLA on the approval-to-carrier handoff, which is where 1,623 orders (1.63%) stall — more than in any later stage. (q09)

## 2. Sizing: what halving late deliveries is worth (estimate)

If late deliveries fell by half (3,267 orders) and those orders behaved like today's on-time orders, roughly 1,546 one-star reviews would be avoided per equivalent period. The retention effect is negligible: buyers whose first order was late repeat at 2.52% versus 3.04% after an on-time first order, so the same change yields about 16 extra repeat orders (≈R$2.3K). The value of fixing lateness sits in ratings and marketplace conversion, not in repeat GMV. This is a sizing under a stated assumption, not a measured impact. (q10)

## 3. Seller risk is concentrated

Thirty sellers — the top 1% — generate 25.9% of GMV; the top 5% (150 sellers) generate 53.2%; the bottom 80% (2,370 sellers) share 17.5%. Any account-management or SLA programme should start with the 150, and losing a handful of them is a material revenue event. (q03)

Among sellers with 50+ delivered orders, on-time rates range from 69.9% to 100%; the network average is 93.2%. The worst decile is identifiable by state, which makes it a workable list for seller-success teams. (q07)

## 4. The marketplace does not retain buyers

Only 3.04% of buyers ever place a second order; monthly cohort retention in month 1 is between 0.02% and 0.71% for every cohort with 100+ buyers. Growth in this period was entirely acquisition. This is consistent with Olist selling through third-party marketplaces where the buyer relationship belongs to the channel. (q04)

**Implication.** Retention-based initiatives (loyalty, CRM) would act on a 3% base. Spend on conversion and rating quality instead.

## 5. Freight burden and delivery time move together

In Maranhão freight is 20.8% of what the customer pays, delivery averages 21.5 days, and 17.4% of parcels are late. In São Paulo state the figures are far lower on all three. Remote buyers pay the most for the slowest, least reliable service, which is where the promise-date lever in section 1 bites hardest. (q05)

## 6. Instalments are the basket-size lever

Credit card carries 75.5% of orders at 3.55 instalments on average. Orders paid in 7–10 instalments average R$333.50 against R$120.21 for single-payment orders (2.8×); 48.5% of orders pay in one go. Category matters: watches_gifts has AOV R$208 and the lowest freight share (7.8%), health_beauty is the largest category at R$1.23M (9.4% of GMV). (q06, q08)

## Caveats

- Lateness is measured against Olist's own estimated date; the dataset does not record how that estimate was set.
- Reviews are per order; an order with several sellers assigns the same score to each.
- Correlations in sections 1 and 5 are not causal claims; section 2 states its assumption.
