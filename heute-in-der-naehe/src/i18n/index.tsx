import { createContext, useContext } from 'react';
import { de, type Dict } from './de';
import { en } from './en';
import { fr } from './fr';
import type { Lang } from '../types';

const dicts: Record<Lang, Dict> = { de, en, fr };

export function detectLang(): Lang {
  const nav = (navigator.language || 'en').toLowerCase();
  if (nav.startsWith('de')) return 'de';
  if (nav.startsWith('fr')) return 'fr';
  return 'en';
}

export function resolveLang(setting: Lang | 'auto'): Lang {
  return setting === 'auto' ? detectLang() : setting;
}

export function getDict(lang: Lang): Dict {
  return dicts[lang] ?? en;
}

export type TFunc = (key: keyof Dict) => string;

export const I18nContext = createContext<{ t: TFunc; lang: Lang }>({
  t: (k) => en[k],
  lang: 'en',
});

export function useT() {
  return useContext(I18nContext);
}
