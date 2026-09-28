import { HttpErrorResponse } from '@angular/common/http';
export function errorMessage(error: unknown): string {
  if (error instanceof HttpErrorResponse) {
    if (error.status === 0) return 'No pudimos conectar. Revisa tu conexión e inténtalo otra vez.';
    if (error.status === 401) return 'Tu sesión no es válida. Revisa tus credenciales o vuelve a ingresar.';
    const body: unknown = error.error;
    if (typeof body === 'object' && body !== null && 'message' in body && typeof body.message === 'string') return body.message;
    return 'No se pudo completar la operación. Inténtalo de nuevo.';
  }
  return error instanceof Error ? error.message : 'Ocurrió un error inesperado.';
}
