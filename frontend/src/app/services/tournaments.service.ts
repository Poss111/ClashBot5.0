import { HttpClient } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { API_BASE_URL } from './api-tokens';

export interface Tournament {
  tournamentId: string;
  name?: string;
  startTime: string;
  region?: string;
  status?: string;
}

export interface RegistrationPayload {
  playerId: string;
  preferredRoles?: string[];
  availability?: string;
}

@Injectable({ providedIn: 'root' })
export class TournamentsService {
  constructor(private http: HttpClient, @Inject(API_BASE_URL) private baseUrl: string) {}

  list() {
    return this.http.get<{ items: Tournament[] }>(`${this.baseUrl}/tournaments`);
  }

  get(id: string) {
    return this.http.get<Tournament>(`${this.baseUrl}/tournaments/${id}`);
  }

  register(id: string, payload: RegistrationPayload) {
    return this.http.post(`${this.baseUrl}/tournaments/${id}/registrations`, payload);
  }
}

