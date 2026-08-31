/**
 * Web FCM: tarayıcı sekmesi kapalıyken de OS bildirimi.
 * google-services / VAPID yoksa sessizce kapanır; CrmOsNotify yedek kalır.
 */
(function (w) {
	'use strict';

	var FIREBASE_SURUM = '10.14.1';
	var aktif = false;
	var sonJeton = '';
	var baslatPromise = null;

	function apiKok() {
		return String(w.CRM_API_BASE || 'http://127.0.0.1:8000').replace(/\/$/, '');
	}

	function tokenAl() {
		try { return localStorage.getItem('crm-auth-token'); } catch (e) { return null; }
	}

	function guvenliBaglam() {
		return w.isSecureContext === true;
	}

	function scriptYukle(src) {
		return new Promise(function (ok, hata) {
			var varMi = document.querySelector('script[src="' + src + '"]');
			if (varMi) { ok(); return; }
			var s = document.createElement('script');
			s.src = src;
			s.async = true;
			s.onload = function () { ok(); };
			s.onerror = function () { hata(new Error('script yüklenemedi: ' + src)); };
			document.head.appendChild(s);
		});
	}

	function ayarCek() {
		return fetch(apiKok() + '/api/fcm-web-ayar', { headers: { Accept: 'application/json' } })
			.then(function (r) { return r.json(); });
	}

	function jetonKaydet(jeton) {
		var t = tokenAl();
		if (!t || !jeton) return Promise.resolve();
		sonJeton = jeton;
		return fetch(apiKok() + '/api/cihaz-token', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				Accept: 'application/json',
				Authorization: 'Bearer ' + t
			},
			body: JSON.stringify({ token: jeton, platform: 'web' })
		}).then(function (r) {
			if (!r.ok) throw new Error('cihaz jetonu kaydedilemedi');
		});
	}

	function jetonSil() {
		var t = tokenAl();
		var jeton = sonJeton;
		if (!jeton && w.firebase && firebase.messaging) {
			try {
				return firebase.messaging().getToken().then(function (j) {
					return jetonSilIle(t, j);
				}).catch(function () { return undefined; });
			} catch (e) {
				return Promise.resolve();
			}
		}
		return jetonSilIle(t, jeton);
	}

	function jetonSilIle(auth, jeton) {
		if (!auth || !jeton) return Promise.resolve();
		return fetch(apiKok() + '/api/cihaz-token?token=' + encodeURIComponent(jeton), {
			method: 'DELETE',
			headers: { Accept: 'application/json', Authorization: 'Bearer ' + auth }
		}).then(function () { sonJeton = ''; }).catch(function () {});
	}

	function baslat() {
		if (baslatPromise) return baslatPromise;
		if (!guvenliBaglam() || !('serviceWorker' in navigator) || !tokenAl())
			return Promise.resolve();
		baslatPromise = ayarCek().then(function (ayar) {
			if (!ayar || !ayar.enabled || !ayar.firebase || !ayar.vapidKey) {
				aktif = false;
				return;
			}
			var gstatic = 'https://www.gstatic.com/firebasejs/' + FIREBASE_SURUM + '/';
			return scriptYukle(gstatic + 'firebase-app-compat.js')
				.then(function () { return scriptYukle(gstatic + 'firebase-messaging-compat.js'); })
				.then(function () {
					if (!firebase.apps.length)
						firebase.initializeApp(ayar.firebase);
					var swUrl = 'firebase-messaging-sw.js?api=' + encodeURIComponent(apiKok());
					return navigator.serviceWorker.register(swUrl).then(function (reg) {
						return navigator.serviceWorker.ready.then(function () { return reg; });
					}).then(function (reg) {
						var messaging = firebase.messaging();
						messaging.onMessage(function (payload) {
							var n = (payload && payload.notification) || {};
							if (w.CrmOsNotify && typeof CrmOsNotify.goster === 'function')
								CrmOsNotify.goster(n.title, n.body);
						});
						return messaging.getToken({
							vapidKey: ayar.vapidKey,
							serviceWorkerRegistration: reg
						}).then(function (jeton) {
							if (!jeton) return;
							aktif = true;
							return jetonKaydet(jeton);
						});
					});
				});
		}).catch(function (e) {
			aktif = false;
			baslatPromise = null;
			try { console.warn('[FCM web]', e && e.message ? e.message : e); } catch (ignore) {}
		});
		return baslatPromise;
	}

	w.CrmWebFcm = {
		baslat: baslat,
		tokenuSil: jetonSil,
		aktifMi: function () { return aktif; }
	};

	if (document.readyState === 'loading')
		document.addEventListener('DOMContentLoaded', function () { baslat(); });
	else
		baslat();
})(window);
