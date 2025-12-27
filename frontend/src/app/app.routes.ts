import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () =>
      import('./components/home.component').then((m) => m.HomeComponent)
  },
  {
    path: 'tournaments',
    loadComponent: () =>
      import('./components/tournaments-list.component').then((m) => m.TournamentsListComponent)
  },
  {
    path: '**',
    redirectTo: ''
  }
];

