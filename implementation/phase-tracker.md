# Phase Tracker (Single Source of Truth)

Bu dosya tum fazlarin ilerleme durumunu tek yerden takip eder.
Her PR/commit sonunda ilgili satiri ve faz dosyasini guncelle.

## Status Legend

- `not-started`
- `in-progress`
- `blocked`
- `done`
- `beta-frozen`

## Master Board

| Phase | Name | Status | Owner | Started | Target | Completed | Checklist |
|---|---|---|---|---|---|---|---|
| 1 | Foundation & Repo Standards | done | @team | 2026-03-06 | 2026-03-06 | 2026-03-06 | [phase-01](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-01.md) |
| 2 | CLI Core & Router | done | @team | 2026-03-06 | 2026-03-06 | 2026-03-06 | [phase-02](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-02.md) |
| 3 | OS Detection & Core Prereq Guard | done | @team | 2026-03-06 | 2026-03-06 | 2026-03-06 | [phase-03](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-03.md) |
| 4 | Site Registry & Onboarding | done | @team | 2026-03-06 | 2026-03-07 | 2026-03-07 | [phase-04](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-04.md) |
| 5 | Multi-Webserver Parity | done | @team | 2026-03-07 | 2026-03-07 | 2026-03-07 | [phase-05](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-05.md) |
| 6 | Native Service Orchestration | done | @team | 2026-03-07 | 2026-03-07 | 2026-03-07 | [phase-06](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-06.md) |
| 7 | Docker-Lite Mode | beta-frozen | @team | 2026-03-07 | 2026-03-10 | 2026-03-10 | [phase-07](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-07.md) |
| 8 | Laradock Bridge Mode | done | @team | 2026-03-10 | 2026-03-11 | 2026-04-03 | [phase-08](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-08.md) |
| 9 | Observability, Ops, Production | done | @team | 2026-04-03 | 2026-04-03 | 2026-04-03 | [phase-09](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-09.md) |
| 10 | Stabilization, Release, Adapter-Readiness | done | @team | 2026-04-03 | 2026-04-04 | 2026-04-03 | [phase-10](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-10.md) |
| 11 | Native Adapter Contract Parity | done | @team | 2026-04-03 | 2026-04-05 | 2026-07-25 | [phase-11](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-11.md) |
| 12 | Native Host Service Provisioning | done | @team | 2026-07-25 | 2026-07-26 | 2026-07-25 | [phase-12](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-12.md) |
| 13 | Deploy Apply + Operate Journey | done | @team | 2026-07-25 | 2026-07-26 | 2026-07-25 | [phase-13](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-13.md) |
| 14 | CI, Golden Contract, Release Packaging | done | @team | 2026-07-25 | 2026-07-26 | 2026-07-25 | [phase-14](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-14.md) |
| 15 | Scheduler, Queue Ops & Manifest Alignment | done | @team | 2026-07-28 | 2026-07-28 | 2026-07-28 | [phase-15](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-15.md) |
| 16 | Project plume.yml v2 (MVP) | done | @team | 2026-07-28 | TBD | 2026-07-29 | [phase-16](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-16.md) |
| 17 | Native Stack Host Parity | done | @team | 2026-08-04 | TBD | 2026-08-04 | [phase-17](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-17.md) |
| 18 | Native pgAdmin (PostgreSQL UI) | done | @team | 2026-08-07 | 2026-08-07 | 2026-08-07 | [phase-18](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-18.md) |
| 19 | Native service contract (Laradock-container UX) | done | @team | 2026-08-12 | 2026-08-12 | 2026-08-12 | [phase-19](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-19.md) |
| 20 | Native cache/broker (memcached + webuis) | done | @team | 2026-08-12 | 2026-08-12 | 2026-08-12 | [phase-20](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-20.md) |
| 21 | Queue honesty + ecosystem backlog | done | @team | 2026-08-12 | 2026-08-12 | 2026-08-12 | [phase-21](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-21.md) |
| 22 | Native supervisor + Horizon worker | done | @team | 2026-08-18 | 2026-08-18 | 2026-08-18 | [phase-22](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-22.md) |
| 23 | Supervisor doctor + upgrade --force + program conf | done | @team | 2026-08-30 | 2026-08-30 | 2026-08-30 | [phase-23](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-23.md) |
| 27 | Composer + Node workspace CLI (Herd P4) | done | @team | 2026-09-27 | 2026-09-29 | 2026-09-29 | [phase-27](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-27.md) |
| 28 | Release packaging (Herd P3) | done | @team | 2026-09-29 | 2026-09-29 | 2026-09-29 | [phase-28](/Users/oguzhan/Desktop/Projects.nosync/larasite/implementation/phases/phase-28.md) |

## Update Rules

1. Kod degisikligi hangi faza aitse, o faz checklist dosyasinda ilgili maddeleri isaretle.
2. Faz tamamlanmadan `status=done` yapma.
3. Faz kapanisinda gate maddelerinin hepsi tamam olmali.
4. Her faz kapanisinda `implementation/05-decision-log.md` kaydi zorunlu.
5. Her fazda ilgili komut dokumanlari ve operation dokumanlari guncel olmali.
