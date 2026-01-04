export interface Tournament {
  tournamentId: string;
  name?: string;
  startTime: string;
  region?: string;
  status?: 'upcoming' | 'active' | 'closed' | 'locked';
  bracket?: string;
}

export interface Team {
  teamId: string;
  tournamentId: string;
  displayName?: string;
  captainSummoner?: string;
  captainDisplayName?: string;
  createdBy?: string;
  createdByDisplayName?: string;
  createdAt?: string;
  members?: Record<string, string>;
  memberDisplayNames?: Record<string, string>;
  status?: 'open' | 'locked';
}

export interface Registration {
  tournamentId: string;
  playerId: string;
  preferredRoles?: string[];
  teamId?: string;
  status?: 'pending' | 'assigned';
}

