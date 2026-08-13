import { appendFileSync, mkdirSync } from 'node:fs'
import { dirname } from 'node:path'

export function apply(ctx, config) {
  mkdirSync(dirname(config.markerPath), { recursive: true })
  appendFileSync(config.markerPath, `${config.activatedMarker}\n`)
  ctx.effect(() => () => {
    appendFileSync(config.markerPath, `${config.disposedMarker}\n`)
  })
}
