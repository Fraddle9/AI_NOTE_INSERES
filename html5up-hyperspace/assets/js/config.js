/**
 * Merkezi API kök adresi.
 * Öncelik: geçerli localStorage 'crm-api-base' → sayfa hostname:8000 → localhost:8000
 *
 * Eski DHCP IP'leri (ör. 192.168.1.122) localStorage'da kalırsa tarayıcı
 * "Failed to fetch" verir; sayfa localhost'tan açıldığında LAN kaydı yok sayılır.
 */
(function () {
	'use strict';
	var stored = null;
	var host = (window.location && window.location.hostname) || '';
	var proto = (window.location && window.location.protocol) || 'http:';
	if (proto === 'file:') proto = 'http:';
	var def = 'http://127.0.0.1:8000';
	var pageIsLocal = !host || host === 'localhost' || host === '127.0.0.1';

	function lanMi(h) {
		return /^(192\.168\.|10\.|172\.(1[6-9]|2\d|3[0-1])\.)/.test(h || '');
	}

	try {
		stored = localStorage.getItem('crm-api-base');
	} catch (e) {}

	if (stored) {
		try {
			var storedHost = new URL(stored).hostname;
			if (pageIsLocal && lanMi(storedHost) && storedHost !== host) {
				stored = null;
				try { localStorage.removeItem('crm-api-base'); } catch (e2) {}
			}
		} catch (e) {
			stored = null;
		}
	}

	if (!stored && host && !pageIsLocal) {
		def = proto + '//' + host + ':8000';
	}
	window.CRM_API_BASE = String(stored || def).replace(/\/$/, '');
})();
