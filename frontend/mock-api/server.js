#!/usr/bin/env node
import express from 'express';
import cors from 'cors';
import morgan from 'morgan';

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

const PORT = process.env.PORT ? Number(process.env.PORT) : 4000;
const API_PREFIX = process.env.API_PREFIX || '/api';
const STAGE = process.env.STAGE || '/dev'; // should match APP_ENV stage in the UI (e.g., /dev or /prod)

// In-memory mock data
const tournaments = new Map();
const teams = new Map(); // key: tournamentId -> list of teams

function seed() {
  const reg = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  const start = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
  const now = new Date();

  const upcoming = {
    tournamentId: 'tourn-1',
    themeId: 1,
    nameKey: 'mock_cup',
    nameKeySecondary: 'mock_secondary',
    schedule: [{ registrationTime: reg, startTime: start }],
    startTime: start,
    registrationTime: reg,
    status: 'upcoming',
    createdAt: now.toISOString(),
    updatedAt: now.toISOString()
  };

  const closed = {
    tournamentId: 'tourn-closed',
    themeId: 2,
    nameKey: 'closed_cup',
    nameKeySecondary: 'Closed Clash',
    schedule: [{ registrationTime: new Date(now.getTime() - 72 * 3600 * 1000).toISOString(), startTime: new Date(now.getTime() - 48 * 3600 * 1000).toISOString() }],
    startTime: new Date(now.getTime() - 48 * 3600 * 1000).toISOString(),
    registrationTime: new Date(now.getTime() - 72 * 3600 * 1000).toISOString(),
    status: 'closed',
    createdAt: now.toISOString(),
    updatedAt: now.toISOString()
  };

  const cancelled = {
    tournamentId: 'tourn-cancelled',
    themeId: 3,
    nameKey: 'cancelled_cup',
    nameKeySecondary: 'Cancelled Clash',
    schedule: [{ registrationTime: new Date(now.getTime() - 24 * 3600 * 1000).toISOString(), startTime: new Date(now.getTime() - 12 * 3600 * 1000).toISOString() }],
    startTime: new Date(now.getTime() - 12 * 3600 * 1000).toISOString(),
    registrationTime: new Date(now.getTime() - 24 * 3600 * 1000).toISOString(),
    status: 'cancelled',
    createdAt: now.toISOString(),
    updatedAt: now.toISOString()
  };

  const inProgress = {
    tournamentId: 'tourn-live',
    themeId: 4,
    nameKey: 'live_cup',
    nameKeySecondary: 'Live Clash',
    schedule: [{ registrationTime: new Date(now.getTime() - 2 * 3600 * 1000).toISOString(), startTime: new Date(now.getTime() - 30 * 60 * 1000).toISOString() }],
    startTime: new Date(now.getTime() - 30 * 60 * 1000).toISOString(),
    registrationTime: new Date(now.getTime() - 2 * 3600 * 1000).toISOString(),
    status: 'in_progress',
    createdAt: now.toISOString(),
    updatedAt: now.toISOString()
  };

  [upcoming, closed, cancelled, inProgress].forEach((t) => {
    tournaments.set(t.tournamentId, t);
  });

  teams.set(upcoming.tournamentId, [
    {
      teamId: 'team-1',
      tournamentId: upcoming.tournamentId,
      captainSummoner: 'CaptainMock',
      members: {
        Top: 'PlayerTop',
        Jungle: 'PlayerJg',
        Mid: 'PlayerMid',
        Bot: 'PlayerBot',
        Support: 'PlayerSup'
      },
      status: 'open'
    },
    {
      teamId: 'team-2',
      tournamentId: upcoming.tournamentId,
      captainSummoner: 'PartialCaptain',
      members: {
        Top: 'TopPlaceholder',
        Jungle: 'Open',
        Mid: 'MidPlaceholder',
        Bot: 'Open',
        Support: 'Open'
      },
      status: 'open'
    }
  ]);
}

seed();

function withAuth(req, res, next) {
  // Accept any bearer token; only used by UI to toggle logged-in state.
  const auth = req.get('authorization') || '';
  if (!auth.toLowerCase().startsWith('bearer ')) {
    // Allow through but mark unauthenticated; UI may still show unauth screens.
    req.user = null;
    return next();
  }
  req.user = { email: 'mock@user', role: 'GENERAL_USER' };
  return next();
}

const router = express.Router();

router.post('/auth/token', (req, res) => {
  // Always issue a mock token and role.
  res.json({
    token: 'mock-jwt-token',
    role: 'GENERAL_USER',
    exp: Math.floor(Date.now() / 1000) + 60 * 60 * 12
  });
});

router.get('/tournaments', withAuth, (req, res) => {
  res.json({ items: Array.from(tournaments.values()) });
});

router.get('/tournaments/:id', withAuth, (req, res) => {
  const t = tournaments.get(req.params.id);
  if (!t) return res.status(404).json({ message: 'Not found' });
  res.json(t);
});

router.post('/tournaments', withAuth, (req, res) => {
  const body = req.body || {};
  const id = body.tournamentId || `tourn-${Date.now()}`;
  const now = new Date().toISOString();
  const primarySchedule = (body.schedule && body.schedule[0]) || {};
  const registrationTime = primarySchedule.registrationTime || body.registrationTime || now;
  const startTime = primarySchedule.startTime || body.startTime || new Date(Date.now() + 3600000).toISOString();
  const record = {
    tournamentId: id,
    themeId: body.themeId ?? 1,
    nameKey: body.nameKey || 'tournament_name',
    nameKeySecondary: body.nameKeySecondary || 'tournament_secondary',
    schedule: body.schedule || [{ registrationTime, startTime }],
    startTime,
    registrationTime,
    status: body.status || 'upcoming',
    createdAt: now,
    updatedAt: now
  };
  tournaments.set(id, record);
  res.status(201).json(record);
});

router.put('/tournaments/:id', withAuth, (req, res) => {
  const existing = tournaments.get(req.params.id);
  if (!existing) return res.status(404).json({ message: 'Not found' });
  const body = req.body || {};
  const primarySchedule = (body.schedule && body.schedule[0]) || {};
  const registrationTime = primarySchedule.registrationTime || body.registrationTime || existing.registrationTime;
  const startTime = primarySchedule.startTime || body.startTime || existing.startTime;
  const updated = {
    ...existing,
    ...body,
    schedule: body.schedule || existing.schedule,
    registrationTime,
    startTime,
    updatedAt: new Date().toISOString()
  };
  tournaments.set(req.params.id, updated);
  res.json(updated);
});

router.post('/tournaments/:id/registrations', withAuth, (req, res) => {
  const body = req.body || {};
  if (!body.playerId) return res.status(400).json({ message: 'playerId is required' });
  res.status(201).json({
    tournamentId: req.params.id,
    playerId: body.playerId,
    status: 'pending'
  });
});

router.get('/tournaments/:id/teams', withAuth, (req, res) => {
  const list = teams.get(req.params.id) || [];
  res.json({ items: list });
});

router.post('/tournaments/:id/teams/:teamId/roles/:role', withAuth, (req, res) => {
  const list = teams.get(req.params.id) || [];
  const team = list.find((t) => t.teamId === req.params.teamId);
  if (!team) return res.status(404).json({ message: 'Team not found' });
  const roleKey = req.params.role;
  const current = team.members?.[roleKey];
  if (current && current !== 'Open') {
    return res.status(400).json({ message: 'role is already filled' });
  }
  const playerId = req.body?.playerId || 'mock-player';
  team.members = team.members || {};
  team.members[roleKey] = playerId;
  return res.json({ teamId: team.teamId, role: roleKey, playerId });
});

router.post('/tournaments/:id/assign', withAuth, (req, res) => {
  res.status(202).json({
    executionArn: `arn:aws:states:mock:${Date.now()}`,
    tournamentId: req.params.id
  });
});

app.use(`${API_PREFIX}${STAGE}`, router);

app.listen(PORT, () => {
  console.log(`Mock API listening on http://localhost:${PORT}${API_PREFIX}${STAGE}`);
});

