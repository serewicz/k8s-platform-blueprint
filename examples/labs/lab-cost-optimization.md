# Lab: Cost Optimization Walkthrough

**Time**: 20–30 minutes
**Prerequisites**: Completed Lab 1 (local platform running)

## Objectives
- Understand how OpenCost allocates cost
- See the impact of missing labels vs. good labels
- Run a savings simulation with realistic education platform numbers
- Identify quick wins visible in the dashboard

## Steps

1. Port-forward OpenCost:
   ```bash
   kubectl port-forward -n opencost svc/opencost 9003:9003
   ```
   Open http://localhost:9003

2. Observe that many namespaces may show "unallocated" until labels are present.

3. Apply a properly labeled workload and watch allocation update (may take 1-2 scrape cycles).

4. Run the simulation tool with numbers that match a global education platform:

   ```bash
   ./scripts/cost-simulation.sh \
     --scenario education-platform \
     --nodes 120 \
     --spot-percent 65 \
     --rightsize-aggressiveness high \
     --active-learners 420000 \
     --output-format markdown
   ```

5. Review the output. Copy key numbers into a slide or note for later discussion.

6. (Advanced) Edit one of the sample deployments to remove resource requests and re-apply. Observe policy denial (or warning) and the cost modeling impact.

## Executive Takeaway

You have now generated the same style of numbers that platform teams present in monthly business reviews and quarterly board updates:
- Baseline vs. optimized monthly cost
- Cost per active learner
- Contribution of spot + right-sizing + consolidation

This is the quantitative foundation for "we can save $X million annually with these three initiatives."
