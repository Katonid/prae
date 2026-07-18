import { useRegisterSW } from 'virtual:pwa-register/react';
import { useT } from '../i18n';

/** Shows a toast when the service worker has a new app version ready. */
export function UpdateToast() {
  const { t } = useT();
  const {
    needRefresh: [needRefresh, setNeedRefresh],
    updateServiceWorker,
  } = useRegisterSW({ immediate: true });

  if (!needRefresh) return null;

  return (
    <div className="update-toast" role="alert">
      <span>🔄 {t('updateAvailable')}</span>
      <button className="btn btn-primary btn-small" onClick={() => void updateServiceWorker(true)}>
        {t('updateNow')}
      </button>
      <button className="btn btn-small" onClick={() => setNeedRefresh(false)}>
        {t('later')}
      </button>
    </div>
  );
}
