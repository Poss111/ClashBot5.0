import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatIconModule } from '@angular/material/icon';
import { TournamentsService, Tournament } from '../services/tournaments.service';
import { AssignmentsService } from '../services/assignments.service';

@Component({
  standalone: true,
  selector: 'app-tournaments-list',
  imports: [
    CommonModule,
    FormsModule,
    MatCardModule,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
    MatProgressSpinnerModule,
    MatIconModule
  ],
  template: `
    <div class="toolbar">
      <button mat-raised-button color="primary" (click)="load()" [disabled]="loading">
        Refresh
      </button>
      <span class="spacer"></span>
      <mat-progress-spinner
        *ngIf="loading"
        diameter="28"
        mode="indeterminate"
        strokeWidth="4"
      ></mat-progress-spinner>
    </div>

    <mat-card *ngIf="error" class="state-card error">
      <mat-icon>error</mat-icon>
      <span>{{ error }}</span>
    </mat-card>

    <mat-card *ngIf="backendUnreachable" class="state-card offline">
      <mat-icon>cloud_off</mat-icon>
      <div>
        <div class="title">Backend is unreachable</div>
        <div class="muted">
          Check API availability, VPN/proxy settings, or try again shortly. If the API was recently
          deployed, allow a minute for the endpoint to warm up.
        </div>
      </div>
    </mat-card>

    <mat-card *ngIf="message" class="state-card success">
      <mat-icon>check_circle</mat-icon>
      <span>{{ message }}</span>
    </mat-card>

    <mat-card *ngFor="let t of tournaments" class="card">
      <mat-card-header>
        <mat-card-title>{{ t.name || t.tournamentId }}</mat-card-title>
        <mat-card-subtitle class="muted">
          {{ t.region || 'region N/A' }} · {{ t.startTime | date: 'medium' }} · status:
          {{ t.status }}
        </mat-card-subtitle>
      </mat-card-header>

      <mat-card-content>
        <div class="form-inline">
          <mat-form-field appearance="outline">
            <mat-label>Player ID</mat-label>
            <input matInput [(ngModel)]="form.playerId" placeholder="discord or summoner" />
          </mat-form-field>

          <mat-form-field appearance="outline">
            <mat-label>Preferred Roles (comma)</mat-label>
            <input matInput [(ngModel)]="form.roles" placeholder="top, jungle" />
          </mat-form-field>
        </div>
      </mat-card-content>

      <mat-card-actions align="end">
        <button
          mat-stroked-button
          color="primary"
          (click)="startAssignment(t.tournamentId)"
          [disabled]="assigning"
        >
          <mat-icon>play_arrow</mat-icon>
          {{ assigning ? 'Starting...' : 'Start assignment' }}
        </button>
        <button mat-raised-button color="accent" (click)="register(t)" [disabled]="submitting">
          <mat-icon>person_add</mat-icon>
          {{ submitting ? 'Submitting...' : 'Register' }}
        </button>
      </mat-card-actions>
    </mat-card>
  `,
  styles: [
    `
      .toolbar {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        margin-bottom: 1rem;
      }
      .spacer {
        flex: 1;
      }
      .card {
        margin-top: 1rem;
      }
      .form-inline {
        display: flex;
        gap: 1rem;
        flex-wrap: wrap;
        margin-top: 0.5rem;
      }
      .muted {
        color: var(--muted-color);
      }
      .state-card {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        margin-bottom: 0.5rem;
      }
      .state-card.error {
        color: #b91c1c;
      }
      .state-card.offline {
        color: #9a3412;
      }
      .state-card.success {
        color: #065f46;
      }
      .title {
        font-weight: 600;
      }
    `
  ]
})
export class TournamentsListComponent {
  tournaments: Tournament[] = [];
  loading = false;
  submitting = false;
  assigning = false;
  error = '';
  message = '';
  backendUnreachable = false;

  form = {
    playerId: '',
    roles: ''
  };

  constructor(
    private tournamentsService: TournamentsService,
    private assignmentsService: AssignmentsService
  ) {
    this.load();
  }

  async load() {
    this.loading = true;
    this.error = '';
    this.backendUnreachable = false;
    try {
      const res = await this.tournamentsService.list().toPromise();
      this.tournaments = res?.items ?? [];
    } catch (err: any) {
      this.error = err?.message ?? 'Failed to load tournaments';
      if (err?.status === 0 || err?.name === 'HttpErrorResponse') {
        this.backendUnreachable = true;
      }
    } finally {
      this.loading = false;
    }
  }

  async register(tournament: Tournament) {
    if (!this.form.playerId) {
      this.error = 'Player ID required';
      return;
    }
    this.submitting = true;
    this.error = '';
    this.message = '';
    this.backendUnreachable = false;
    try {
      await this.tournamentsService
        .register(tournament.tournamentId, {
          playerId: this.form.playerId,
          preferredRoles: this.form.roles
            ? this.form.roles.split(',').map((r) => r.trim())
            : []
        })
        .toPromise();
      this.message = 'Registration submitted';
      this.form.playerId = '';
      this.form.roles = '';
    } catch (err: any) {
      this.error = err?.message ?? 'Failed to register';
      if (err?.status === 0 || err?.name === 'HttpErrorResponse') {
        this.backendUnreachable = true;
      }
    } finally {
      this.submitting = false;
    }
  }

  async startAssignment(tournamentId: string) {
    this.assigning = true;
    this.error = '';
    this.message = '';
    this.backendUnreachable = false;
    try {
      await this.assignmentsService.start(tournamentId).toPromise();
      this.message = 'Assignment workflow started';
    } catch (err: any) {
      this.error = err?.message ?? 'Failed to start workflow';
      if (err?.status === 0 || err?.name === 'HttpErrorResponse') {
        this.backendUnreachable = true;
      }
    } finally {
      this.assigning = false;
    }
  }
}

