/**
 * Tarayıcı / işletim sistemi bildirimi (macOS Bildirim Merkezi, Windows toast).
 * Görev atanınca sekme arkada olsa bile görünür.
 * Tarayıcı tamamen kapalıysa web FCM (web-fcm.js + service worker) gerekir.
 */
(function (w) {
	'use strict';

	function destekVarMi() {
		return typeof w.Notification === 'function';
	}

	function izinIste() {
		if (!destekVarMi())
			return Promise.resolve('unsupported');
		if (Notification.permission === 'granted' || Notification.permission === 'denied')
			return Promise.resolve(Notification.permission);
		try {
			return Notification.requestPermission();
		} catch (e) {
			return Promise.resolve('denied');
		}
	}

	function goster(baslik, govde) {
		if (!destekVarMi() || Notification.permission !== 'granted')
			return;
		try {
			var n = new Notification(baslik || 'Size yeni bir görev atandı', {
				body: govde || 'CRM Analiz Portalı',
				tag: 'crm-gorev-atama-' + Date.now(),
				renotify: true
			});
			n.onclick = function () {
				try { w.focus(); } catch (ignore) {}
				try { n.close(); } catch (ignore2) {}
				if (typeof w.crmSekmeyiAc === 'function')
					w.crmSekmeyiAc('gorevler');
			};
		} catch (e) {}
	}

	w.CrmOsNotify = {
		izinIste: izinIste,
		goster: goster,
		destekVarMi: destekVarMi
	};
})(window);
