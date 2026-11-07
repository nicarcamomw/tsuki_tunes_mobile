/**
 * A token bucket per caller: [capacity] requests at once, refilled at
 * [perMinute] a minute. Kept per instance (with few instances allowed, the
 * real limit is a small multiple of this), which is enough to stop a script
 * from hammering Last.fm or Deezer through the proxy.
 */
export class RateLimiter {
  private readonly buckets = new Map<string, { tokens: number; at: number }>();

  constructor(
    private readonly capacity: number,
    private readonly perMinute: number,
    private readonly now: () => number = Date.now,
    private readonly maxCallers = 10000,
  ) {}

  /** Whether [key] may make one more request now (and counts it). */
  allow(key: string): boolean {
    const now = this.now();
    const bucket = this.buckets.get(key) ?? { tokens: this.capacity, at: now };
    const refill = ((now - bucket.at) / 60000) * this.perMinute;
    bucket.tokens = Math.min(this.capacity, bucket.tokens + refill);
    bucket.at = now;
    const allowed = bucket.tokens >= 1;
    if (allowed) bucket.tokens -= 1;
    this.buckets.delete(key);
    this.buckets.set(key, bucket);
    if (this.buckets.size > this.maxCallers) {
      const oldest = this.buckets.keys().next().value;
      if (oldest !== undefined) this.buckets.delete(oldest);
    }
    return allowed;
  }
}
