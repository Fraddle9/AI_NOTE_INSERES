/**
 * Firebase web push service worker.
 * Tarayıcı tamamen kapalıyken FCM buraya düşer.
 *
 * Kayıt URL'si: firebase-messaging-sw.js?api=<CRM_API_BASE>
 */
/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

(function () {
	'use strict';
	var api = 'http://127.0.0.1:8000';
	try {
		var u = new URL(self.location.href);
		if (u.searchParams.get('api'))
			api = u.searchParams.get('api');
	} catch (e) {}
	api = String(api).replace(/\/$/, '');
	try {
		importScripts(api + '/api/fcm-web-ayar.js');
	} catch (e) {
		return;
	}
	if (!self.FIREBASE_WEB_ENABLED || !self.FIREBASE_WEB)
		return;
	try {
		firebase.initializeApp(self.FIREBASE_WEB);
	} catch (e2) {
		return;
	}
	var messaging = firebase.messaging();
	messaging.onBackgroundMessage(function (payload) {
		var n = (payload && payload.notification) || {};
		var data = (payload && payload.data) || {};
		if (n.title) {
			// Bildirim yükü varsa tarayıcı çoğu zaman zaten gösterir.
			return;
		}
		return self.registration.showNotification(
			data.title || 'Size yeni bir görev atandı',
			{
				body: data.body || 'CRM Analiz Portalı',
				tag: 'crm-gorev-atama',
				renotify: true,
				data: data
			}
		);
	});
})();

self.addEventListener('notificationclick', function (event) {
	event.notification.close();
	var hedef = './index.html';
	event.waitUntil(
		self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (liste) {
			for (var i = 0; i < liste.length; i++) {
				var c = liste[i];
				if (c.url && 'focus' in c)
					return c.focus();
			}
			if (self.clients.openWindow)
				return self.clients.openWindow(hedef);
		})
	);
});
