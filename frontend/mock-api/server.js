#!/usr/bin/env node
import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import crypto from 'crypto';

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
const users = new Map(); // key: userId/email -> profile

function maskIdentifier(value) {
  if (!value) return 'Player';
  let hash = 0;
  for (let i = 0; i < value.length; i += 1) {
    hash = (hash * 31 + value.charCodeAt(i)) >>> 0;
  }
  const code = hash.toString(16).padStart(6, '0').slice(0, 6);
  return `Player-${code}`;
}

function ensureUser(userId, displayName) {
  if (!users.has(userId)) {
    users.set(userId, {
      userId,
      email: userId,
      displayName: displayName || 'Mock Player',
      lastLogin: new Date().toISOString(),
      createdAt: new Date().toISOString()
    });
  }
  const existing = users.get(userId);
  if (displayName && displayName.trim()) {
    existing.displayName = displayName.trim();
  }
  return existing;
}

function displayNameFor(userId) {
  if (!userId || userId === 'Open') return null;
  const profile = users.get(userId);
  return profile?.displayName || maskIdentifier(userId);
}

function withDisplayNames(team) {
  const memberDisplayNames = {};
  Object.entries(team.members || {}).forEach(([role, member]) => {
    const label = displayNameFor(member);
    if (label) memberDisplayNames[role] = label;
  });
  return {
    ...team,
    captainDisplayName: displayNameFor(team.captainSummoner),
    createdByDisplayName: displayNameFor(team.createdBy),
    memberDisplayNames
  };
}

function seed() {
  const reg = new Date(Date.now() + 60 * 60 * 1000).toISOString();
  const start = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString();
  const now = new Date();

  ensureUser('mock@user', 'Mock Player');

  const upcoming = {
    tournamentId: 'tourn-1',
    themeId: 1,
    nameKey: 'mock_cup',
    nameKeySecondary: 'Clash Night Mock',
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
      captainSummoner: 'mock@user', // make mock user the captain
      createdBy: 'mock@user',
      members: {
        Top: 'mock@user', // mock user is on the team
        Jungle: 'PlayerJg',
        Mid: 'PlayerMid',
        Bot: 'PlayerBot',
        Support: 'PlayerSup'
      },
      memberStatuses: {
        Top: 'maybe', // show a "Maybe" status on the team card
        Jungle: 'all_in',
        Mid: 'all_in',
        Bot: 'all_in',
        Support: 'all_in'
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
      memberStatuses: {
        Top: 'all_in',
        Mid: 'all_in'
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
  const profile = ensureUser('mock@user', 'Mock Player');
  req.user = { email: profile.email, role: 'GENERAL_USER', displayName: profile.displayName };
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

router.get('/users/me', withAuth, (req, res) => {
  if (!req.user) return res.status(401).json({ message: 'Unauthorized' });
  const profile = ensureUser(req.user.email, req.user.displayName);
  return res.json({
    userId: profile.userId,
    email: profile.email,
    displayName: profile.displayName,
    name: profile.displayName,
    createdAt: profile.createdAt,
    lastLogin: profile.lastLogin,
    role: 'GENERAL_USER'
  });
});

router.put('/users/me/display-name', withAuth, (req, res) => {
  if (!req.user) return res.status(401).json({ message: 'Unauthorized' });
  const desired = (req.body?.displayName || '').trim();
  const valid = desired.length >= 3 && desired.length <= 32 && /^[a-zA-Z0-9 _.'-]+$/.test(desired) && !desired.includes('@');
  if (!valid) {
    return res.status(400).json({ message: 'displayName must be 3-32 characters and not an email' });
  }
  const profile = ensureUser(req.user.email, desired);
  return res.json({
    userId: profile.userId,
    email: profile.email,
    displayName: profile.displayName,
    name: profile.displayName,
    createdAt: profile.createdAt,
    lastLogin: new Date().toISOString(),
    role: 'GENERAL_USER'
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
  const list = (teams.get(req.params.id) || []).map(withDisplayNames);
  res.json({ items: list });
});

router.post('/tournaments/:id/teams', withAuth, (req, res) => {
  if (!req.user) return res.status(401).json({ message: 'Unauthorized' });
  const profile = ensureUser(req.user.email, req.user.displayName);
  const body = req.body || {};
  const displayName = (body.displayName || body.teamName || '').trim();
  const role = (body.role || '').trim();
  if (!displayName) return res.status(400).json({ message: 'displayName is required' });
  if (!role) return res.status(400).json({ message: 'role is required' });

  const list = teams.get(req.params.id) || [];
  const alreadyMember = list.some((t) => Object.values(t.members || {}).some((v) => v === req.user.email));
  if (alreadyMember) {
    return res.status(400).json({ message: 'user already belongs to a team for this tournament; disband first' });
  }
  const members = (body.members && typeof body.members === 'object') ? body.members : {};
  members[role] = req.user.email;
  const memberStatuses = { ...(body.memberStatuses || {}) };
  memberStatuses[role] = 'all_in';
  const teamId = crypto.randomUUID();
  const item = {
    teamId,
    tournamentId: req.params.id,
    displayName,
    captainSummoner: req.user.email,
    createdBy: req.user.email,
    createdAt: new Date().toISOString(),
    members,
    memberStatuses,
    status: 'open'
  };

  list.push(item);
  teams.set(req.params.id, list);

  const label = displayNameFor(profile.userId);
  return res.status(201).json({
    ...item,
    captainDisplayName: label,
    createdByDisplayName: label,
    memberDisplayNames: { [role]: label }
  });
});

router.delete('/tournaments/:id/teams/:teamId', withAuth, (req, res) => {
  if (!req.user) return res.status(401).json({ message: 'Unauthorized' });
  const list = teams.get(req.params.id) || [];
  const idx = list.findIndex((t) => t.teamId === req.params.teamId);
  if (idx < 0) return res.status(404).json({ message: 'Team not found' });
  const team = list[idx];
  const isCaptain = team.captainSummoner === req.user.email || team.createdBy === req.user.email;
  if (!isCaptain) return res.status(403).json({ message: 'Only captain can delete' });
  list.splice(idx, 1);
  teams.set(req.params.id, list);
  return res.json({ deleted: true, teamId: req.params.teamId });
});

router.post('/tournaments/:id/teams/:teamId/roles/:role', withAuth, (req, res) => {
  const list = teams.get(req.params.id) || [];
  const team = list.find((t) => t.teamId === req.params.teamId);
  if (!team) return res.status(404).json({ message: 'Team not found' });
  const roleKey = req.params.role;
  const current = team.members?.[roleKey];
  const playerId = req.body?.playerId || 'mock-player';
  ensureUser(playerId);

  // Allow swap: if user already on team in another role, clear that role first.
  const existingRole = Object.entries(team.members || {}).find(([, v]) => v === playerId)?.[0];
  // Rule: user cannot be on multiple teams in same tournament.
  const inAnotherTeam = list.some((t) => t.teamId !== team.teamId && Object.values(t.members || {}).some((v) => v === playerId));
  if (inAnotherTeam) {
    return res.status(400).json({ message: 'user already belongs to another team in this tournament' });
  }
  if (current && current !== 'Open' && current !== playerId) {
    return res.status(400).json({ message: 'role is already filled' });
  }
  team.members = team.members || {};
  if (existingRole && existingRole !== roleKey) {
    team.members[existingRole] = 'Open';
    if (team.memberStatuses) delete team.memberStatuses[existingRole];
  }
  team.members[roleKey] = playerId;
  team.memberStatuses = team.memberStatuses || {};
  team.memberStatuses[roleKey] = 'all_in';
  return res.json({ teamId: team.teamId, role: roleKey, playerId, playerDisplayName: displayNameFor(playerId) });
});

router.delete('/tournaments/:id/teams/:teamId/roles/:role', withAuth, (req, res) => {
  if (!req.user) return res.status(401).json({ message: 'Unauthorized' });
  const list = teams.get(req.params.id) || [];
  const team = list.find((t) => t.teamId === req.params.teamId);
  if (!team) return res.status(404).json({ message: 'Team not found' });
  const roleKey = req.params.role;
  const current = team.members?.[roleKey];
  if (!current || current === 'Open') return res.status(404).json({ message: 'role is already open' });
  const isCaptain = team.captainSummoner === req.user.email || team.createdBy === req.user.email;
  if (!isCaptain) return res.status(403).json({ message: 'Only captain can remove' });
  if (current === req.user.email) return res.status(400).json({ message: 'captain cannot kick themselves' });
  team.members[roleKey] = 'Open';
  if (team.memberStatuses) delete team.memberStatuses[roleKey];
  return res.json({ teamId: team.teamId, role: roleKey, removed: current });
});

router.post('/tournaments/:id/assign', withAuth, (req, res) => {
  res.status(202).json({
    executionArn: `arn:aws:states:mock:${Date.now()}`,
    tournamentId: req.params.id
  });
});

// Primary mount: match expected prefix + stage (e.g., /api/dev).
app.use(`${API_PREFIX}${STAGE}`, router);

// Convenience mount: also serve at just the stage (e.g., /dev) so clients
// that omit the /api prefix (or when using a different base URL) still work.
// This improves local DX while keeping the prefixed path for parity with prod.
if (API_PREFIX !== '') {
  app.use(`${STAGE}`, router);
}

app.listen(PORT, () => {
  console.log(`Mock API listening on http://localhost:${PORT}${API_PREFIX}${STAGE}`);
});

