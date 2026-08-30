// Registrierung aller Elemente (Widgets).

import randomizer from './randomizer.js';
import timer from './timer.js';
import clock from './clock.js';
import traffic from './traffic.js';
import checklist from './checklist.js';
import text from './text.js';
import image from './image.js';
import noise from './noise.js';
import symbols from './symbols.js';
import sound from './sound.js';
import video from './video.js';
import camera from './camera.js';
import birthday from './birthday.js';
import seating from './seating.js';

export const WIDGETS = [randomizer, seating, timer, clock, traffic, checklist, text, image, sound, video, camera, noise, symbols, birthday];

const byType = new Map(WIDGETS.map((widget) => [widget.type, widget]));

export function getWidgetType(type) {
  return byType.get(type) || null;
}
