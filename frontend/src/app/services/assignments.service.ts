import { HttpClient } from '@angular/common/http';
import { Inject, Injectable } from '@angular/core';
import { API_BASE_URL } from './api-tokens';

@Injectable({ providedIn: 'root' })
export class AssignmentsService {
  constructor(private http: HttpClient, @Inject(API_BASE_URL) private baseUrl: string) {}

  start(tournamentId: string) {
    return this.http.post<{ executionArn: string }>(
      `${this.baseUrl}/tournaments/${tournamentId}/assign`,
      { tournamentId }
    );
  }
}

