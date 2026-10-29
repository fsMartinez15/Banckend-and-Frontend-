export type Role = 'passenger' | 'driver' | 'admin';
export type RegistrationRole = Exclude<Role, 'admin'>;
export type DocumentType = 'CC' | 'CE' | 'PP' | 'TI';
export type TripStatus = 'pending' | 'accepted' | 'arrived' | 'in_progress' | 'completed' | 'cancelled';
export type PaymentStatus = 'PENDING' | 'APPROVED' | 'DECLINED' | 'VOIDED' | 'ERROR';
export interface Profile {
  id: string; name: string; phone: string | null; role: Role; active: boolean; available: boolean;
  document_type?: DocumentType | null; document_number?: string | null;
}
export interface Trip {
  id: string; passenger_id: string; driver_id: string | null; origin: string; destination: string;
  status: TripStatus; created_at: string; completed_at: string | null; rating: number | null; comment: string | null;
  fare_cents?: number | null; payment_method?: 'cash' | 'wompi';
}
export interface Payment {
  id: string; trip_id: string; passenger_id: string; reference: string; amount_in_cents: number; currency: string;
  status: PaymentStatus; wompi_transaction_id: string | null; payment_method: string | null; created_at: string; updated_at: string;
}
/** identifier: correo electrónico o número de cédula. */
export interface Credentials { identifier: string; password: string; }
export interface Registration {
  email: string; password: string; name: string; role: RegistrationRole;
  documentType: DocumentType; documentNumber: string; phone: string;
}
export interface AuthSession {
  access_token: string | null; refresh_token: string | null; expires_in: number | null;
  token_type: string | null; user: { id: string; email: string } | null;
}
export interface DashboardData { profile: Profile; trips: Trip[]; payments: Payment[]; }
export interface TripRequest { origin: string; destination: string; }
export interface CheckoutLink { url: string; reference: string; amount_in_cents: number; currency: string; }
export interface PaymentResult { reference: string; status: PaymentStatus; amount_in_cents: number; currency: string; payment_method: string | null; }
export const STATUS_LABEL: Record<TripStatus, string> = {
  pending: 'Buscando conductor', accepted: 'Conductor en camino', arrived: 'Conductor llegó', in_progress: 'En camino', completed: 'Finalizado', cancelled: 'Cancelado'
};
export const ROLE_LABEL: Record<Role, string> = { passenger: 'Cliente', driver: 'Conductor', admin: 'Administrador' };
export const DOCUMENT_LABEL: Record<DocumentType, string> = { CC: 'Cédula de ciudadanía', CE: 'Cédula de extranjería', PP: 'Pasaporte', TI: 'Tarjeta de identidad' };
export function formatCop(amountInCents: number): string {
  return new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 }).format(amountInCents / 100);
}
