import { Component, Inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, RouterOutlet } from '@angular/router';
import { HttpClientModule } from '@angular/common/http';
import { MatToolbarModule } from '@angular/material/toolbar';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { API_BASE_URL } from './services/api-tokens';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [
    CommonModule,
    RouterOutlet,
    RouterModule,
    HttpClientModule,
    MatToolbarModule,
    MatButtonModule,
    MatIconModule
  ],
  template: `
    <mat-toolbar color="primary">
      <span class="brand">
        ClashBot
      </span>
      <span class="spacer"></span>
      <a mat-button routerLink="/">Home</a>
      <a mat-button routerLink="/tournaments">Tournaments</a>
      <button mat-button (click)="toggleTheme()" aria-label="Toggle light/dark mode">
        <mat-icon>{{ isDark ? 'light_mode' : 'dark_mode' }}</mat-icon>
        {{ isDark ? 'Light' : 'Dark' }}
      </button>
    </mat-toolbar>

    <main class="layout">
      <router-outlet />
      <footer>
        <small>API: {{ apiBaseUrl }}</small>
      </footer>
    </main>
  `,
  styles: [
    `
      .layout {
        max-width: 960px;
        margin: 0 auto;
        padding: 1.5rem;
        font-family: Inter, Roboto, system-ui, -apple-system, 'Segoe UI', sans-serif;
      }
      .brand {
        display: inline-flex;
        align-items: center;
        gap: 0.25rem;
      }
      header h1 {
        margin: 0 0 0.25rem;
      }
      .muted {
        color: #6b7280;
        margin: 0;
      }
      .spacer {
        flex: 1;
      }
      section {
        margin-top: 1.5rem;
      }
      footer {
        margin-top: 2rem;
        color: #9ca3af;
      }
    `
  ]
})
export class AppComponent {
  isDark = false;

  constructor(@Inject(API_BASE_URL) public apiBaseUrl: string) {}

  ngOnInit(): void {
    const saved = localStorage.getItem('theme');
    this.isDark = saved === 'dark';
    this.applyTheme();
  }

  toggleTheme(): void {
    this.isDark = !this.isDark;
    localStorage.setItem('theme', this.isDark ? 'dark' : 'light');
    this.applyTheme();
  }

  private applyTheme() {
    document.body.classList.toggle('dark-mode', this.isDark);
  }
}

