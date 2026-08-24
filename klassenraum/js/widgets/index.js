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

export const WIDGETS = [randomizer, timer, clock, traffic, checklist, text, image, sound, video, noise, symbols];

const byType = new Map(WIDGETS.map((widget) => [widget.type, widget]));

export function getWidgetType(type) {
  return byType.get(type) || null;
}
