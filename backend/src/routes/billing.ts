import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { getBillingStatus } from '../billing/entitlements.js';
import { config } from '../config.js';

export function createBillingRoutes(): Router {
  const router = Router();

  router.get('/status', requireAuth, async (req, res) => {
    try {
      const status = await getBillingStatus(req.user!.sub);
      res.json(status);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to load billing status';
      res.status(404).json({ error: message });
    }
  });

  router.post('/checkout', requireAuth, async (_req, res) => {
    // Payment fulfillment is intentionally not enabled until Dodo product/API
    // details are finalized. Keeping this endpoint lets the app surface a
    // clear message instead of silently failing.
    if (!config.dodo.apiKey || !config.dodo.productId || !config.dodo.returnUrl) {
      res.status(503).json({
        error: 'Checkout is not configured yet.',
        code: 'checkout_not_configured',
      });
      return;
    }

    res.status(501).json({
      error: 'Dodo checkout integration is pending product setup.',
      code: 'checkout_pending',
    });
  });

  return router;
}
