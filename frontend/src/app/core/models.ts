export type Role = 'passenger' | 'driver' | 'admin';
export type RegistrationRole = Exclude<Role, 'admin'>;
export type TripStatus = 'pending' | 'accepted' | 'in_progress' | 'completed' | 'cancelled';
export interface Profile { id: string; name: string; phone: string | null; role: Role; active: boolean; available: boolean; }
export interface Trip {
  id: string; passenger_id: string; driver_id: string | null; origin: string; destination: string;
  status: TripStatus; created_at: string; completed_at: string | null; rating: number | null; comment: string | null;
}
export interface Credentials { email: string; password: string; }
export interface Registration extends Credentials { name: string; role: RegistrationRole; }
export interface AuthSession {
  access_token: string | null; refresh_token: string | null; expires_in: number | null;
  token_type: string | null; user: { id: string; email: string } | null;
}
export interface DashboardData { profile: Profile; trips: Trip[]; }
export interface TripRequest { origin: string; destination: string; }
export const STATUS_LABEL: Record<TripStatus, string> = {
  pending: 'Buscando conductor', accepted: 'Aceptado', in_progress: 'En camino', completed: 'Finalizado', cancelled: 'Cancelado'
};
export const ROLE_LABEL: Record<Role, string> = { passenger: 'Pasajero', driver: 'Conductor', admin: 'Administrador' };
