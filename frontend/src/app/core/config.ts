import { InjectionToken } from '@angular/core';
export interface AppConfig { apiBaseUrl: string; demoEnabled: boolean; }
export const APP_CONFIG = new InjectionToken<AppConfig>('Runtime configuration');
export function parseConfig(value: unknown): AppConfig {
  if (typeof value !== 'object' || value === null || !('apiBaseUrl' in value) || typeof value.apiBaseUrl !== 'string'
      || !('demoEnabled' in value) || typeof value.demoEnabled !== 'boolean') throw new Error('Configuración incompleta.');
  const url = new URL(value.apiBaseUrl);
  if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password || url.hash || url.search) throw new Error('URL de API inválida.');
  if (url.protocol === 'http:' && !['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)) throw new Error('La API debe usar HTTPS.');
  return { apiBaseUrl: value.apiBaseUrl.replace(/\/+$/, ''), demoEnabled: value.demoEnabled };
}
