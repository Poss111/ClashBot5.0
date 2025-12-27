import { Component, Inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatCardModule } from '@angular/material/card';
import { MatButtonModule } from '@angular/material/button';
import { RouterModule } from '@angular/router';
import { API_BASE_URL } from '../services/api-tokens';

@Component({
  standalone: true,
  selector: 'app-home',
  imports: [CommonModule, MatCardModule, MatButtonModule, RouterModule],
  template: `
    <div class="hero">
      <div>
        <p class="eyebrow">League of Legends Clash</p>
        <h1>Find your squad before Riot opens the gates.</h1>
        <p class="lead">
          ClashBot keeps player signups in one place, matches roles fast, and gets teams ready for
          tournament day without last-minute chaos.
        </p>
        <div class="actions">
          <a mat-raised-button color="primary" routerLink="/tournaments">View tournaments</a>
          <a mat-stroked-button color="accent" href="https://developer.riotgames.com/" target="_blank">
            Riot API docs
          </a>
        </div>
        <div class="meta">API base: {{ apiBaseUrl }}</div>
      </div>
    </div>

    <div class="grid">
      <mat-card>
        <mat-card-title>Theory craft early</mat-card-title>
        <mat-card-content>
          <p>Draft comps, swap roles, and sanity-check your roster before Riot opens registrations.</p>
        </mat-card-content>
      </mat-card>
      <mat-card>
        <mat-card-title>Admin + player flows</mat-card-title>
        <mat-card-content>
          <p>Players register; admins trigger assignments and track team status in one place.</p>
        </mat-card-content>
      </mat-card>
      <mat-card>
        <mat-card-title>Balanced teams faster</mat-card-title>
        <mat-card-content>
          <p>Match roles quickly so every lineup is ready before registrations open in Riot.</p>
        </mat-card-content>
      </mat-card>
    </div>
  `,
  styles: [
    `
      .hero {
        background: var(--hero-bg);
        color: var(--hero-text);
        border-radius: 12px;
        padding: 2rem;
        margin-bottom: 1.5rem;
      }
      .eyebrow {
        text-transform: uppercase;
        letter-spacing: 0.08em;
        font-weight: 600;
        color: #a5b4fc;
        margin: 0 0 0.5rem;
      }
      h1 {
        margin: 0 0 0.75rem;
        line-height: 1.2;
      }
      .lead {
        margin: 0 0 1rem;
        color: var(--hero-muted);
      }
      .actions {
        display: flex;
        gap: 0.75rem;
        align-items: center;
        margin-bottom: 1rem;
      }
      .meta {
        color: #94a3b8;
        font-size: 0.9rem;
      }
      .grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
        gap: 1rem;
      }
      mat-card {
        height: 100%;
        background: var(--card-color);
        color: var(--text-color);
      }
    `
  ]
})
export class HomeComponent {
  constructor(@Inject(API_BASE_URL) public apiBaseUrl: string) {}
}

