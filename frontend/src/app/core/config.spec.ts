import { describe, expect, it } from 'vitest';
import { parseConfig } from './config';
describe('Runtime configuration', () => {
  it('accepts local HTTP and strips trailing slash', () => expect(parseConfig({ apiBaseUrl: 'http://127.0.0.1:8080/', demoEnabled: false }).apiBaseUrl).toBe('http://127.0.0.1:8080'));
  it('rejects incomplete config and remote plain HTTP', () => {
    expect(() => parseConfig({})).toThrow();
    expect(() => parseConfig({ apiBaseUrl: 'http://example.org', demoEnabled: false })).toThrow();
    expect(() => parseConfig({ apiBaseUrl: 'https://user:password@example.org', demoEnabled: false })).toThrow();
  });
});
