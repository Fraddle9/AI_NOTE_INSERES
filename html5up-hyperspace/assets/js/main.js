/*
	Hyperspace by HTML5 UP
	html5up.net | @ajlkn
	Free for personal and commercial use under the CCA 3.0 license (html5up.net/license)
*/

(function($) {

	var	$window = $(window),
		$body = $('body'),
		$sidebar = $('#sidebar');

	// Breakpoints.
		breakpoints({
			xlarge:   [ '1281px',  '1680px' ],
			large:    [ '981px',   '1280px' ],
			medium:   [ '737px',   '980px'  ],
			small:    [ '481px',   '736px'  ],
			xsmall:   [ null,      '480px'  ]
		});

	// Hack: Enable IE flexbox workarounds.
		if (browser.name == 'ie')
			$body.addClass('is-ie');

	// Play initial animations on page load.
		$window.on('load', function() {
			window.setTimeout(function() {
				$body.removeClass('is-preload');
			}, 100);
		});

	// Forms.

		// Hack: Activate non-input submits.
			$('form').on('click', '.submit', function(event) {

				// Stop propagation, default.
					event.stopPropagation();
					event.preventDefault();

				// Submit form.
					$(this).parents('form').submit();

			});

	// Sidebar.
		if ($sidebar.length > 0) {

			var $sidebar_a = $sidebar.find('a');

			$sidebar_a
				.addClass('scrolly')
				.on('click', function() {

					var $this = $(this);

					// External link? Bail.
						if ($this.attr('href').charAt(0) != '#')
							return;

					// Deactivate all links.
						$sidebar_a.removeClass('active');

					// Activate link *and* lock it (so Scrollex doesn't try to activate other links as we're scrolling to this one's section).
						$this
							.addClass('active')
							.addClass('active-locked');

				})
				.each(function() {

					var	$this = $(this),
						id = $this.attr('href'),
						$section = $(id);

					// No section for this link? Bail.
						if ($section.length < 1)
							return;

					// Scrollex.
						$section.scrollex({
							mode: 'middle',
							top: '-20vh',
							bottom: '-20vh',
							initialize: function() {

								// Deactivate section.
									$section.addClass('inactive');

							},
							enter: function() {

								// Activate section.
									$section.removeClass('inactive');

								// No locked links? Deactivate all links and activate this section's one.
									if ($sidebar_a.filter('.active-locked').length == 0) {

										$sidebar_a.removeClass('active');
										$this.addClass('active');

									}

								// Otherwise, if this section's link is the one that's locked, unlock it.
									else if ($this.hasClass('active-locked'))
										$this.removeClass('active-locked');

							}
						});

				});

		}

	// Scrolly.
		$('.scrolly').scrolly({
			speed: 1000,
			offset: function() {

				// If <=large, >small, and sidebar is present, use its height as the offset.
					if (breakpoints.active('<=large')
					&&	!breakpoints.active('<=small')
					&&	$sidebar.length > 0)
						return $sidebar.height();

				return 0;

			}
		});

	// Spotlights.
		$('.spotlights > section')
			.scrollex({
				mode: 'middle',
				top: '-10vh',
				bottom: '-10vh',
				initialize: function() {

					// Deactivate section.
						$(this).addClass('inactive');

				},
				enter: function() {

					// Activate section.
						$(this).removeClass('inactive');

				}
			})
			.each(function() {

				var	$this = $(this),
					$image = $this.find('.image'),
					$img = $image.find('img'),
					x;

				// Assign image.
					$image.css('background-image', 'url(' + $img.attr('src') + ')');

				// Set background position.
					if (x = $img.data('position'))
						$image.css('background-position', x);

				// Hide <img>.
					$img.hide();

			});

	// Features.
		$('.features')
			.scrollex({
				mode: 'middle',
				top: '-20vh',
				bottom: '-20vh',
				initialize: function() {

					// Deactivate section.
						$(this).addClass('inactive');

				},
				enter: function() {

					// Activate section.
						$(this).removeClass('inactive');

				}
			});

})(jQuery);

// Tüm CRM IIFE'leri tarafından paylaşılır (config.js → CRM_API_BASE).
var CRM_API = (window.CRM_API_BASE || 'http://127.0.0.1:8000').replace(/\/$/, '');

(function (w) {
	'use strict';
	function norm(s) {
		return String(s == null ? '' : s).toLocaleLowerCase('tr-TR').replace(/\s+/g, ' ').trim();
	}
	w.CrmQuery = {
		norm: norm,
		match: function (q, parts) {
			q = norm(q);
			if (!q) return true;
			var i;
			for (i = 0; i < parts.length; i++) {
				if (norm(parts[i]).indexOf(q) >= 0)
					return true;
			}
			return false;
		},
		cmp: function (a, b, dir) {
			var mul = dir === 'desc' ? -1 : 1;
			if (a == null || a === '') return 1;
			if (b == null || b === '') return -1;
			if (typeof a === 'number' && typeof b === 'number' && !isNaN(a) && !isNaN(b))
				return (a - b) * mul;
			return String(a).localeCompare(String(b), 'tr', { numeric: true, sensitivity: 'base' }) * mul;
		},
		toggleSort: function (state, key) {
			if (!key) return;
			if (state.sort === key)
				state.dir = state.dir === 'asc' ? 'desc' : 'asc';
			else {
				state.sort = key;
				state.dir = (/^(tarih|due|id|kurumSayisi|created_at|updated_at|eklenme_tarihi)$/i.test(key) || /_id$/i.test(key))
					? 'desc' : 'asc';
			}
		},
		paintSort: function (table, state) {
			if (!table) return;
			Array.prototype.forEach.call(table.querySelectorAll('.crm-sort-btn'), function (btn) {
				var on = btn.getAttribute('data-sort') === state.sort;
				btn.classList.toggle('is-active', on);
				btn.setAttribute('aria-sort', on ? (state.dir === 'desc' ? 'descending' : 'ascending') : 'none');
				var icon = btn.querySelector('.crm-sort-icon');
				if (icon)
					icon.textContent = on ? (state.dir === 'desc' ? '▼' : '▲') : '↕';
			});
		},
		paintColFilter: function (table, state, keys) {
			if (!table) return;
			Array.prototype.forEach.call(table.querySelectorAll('.crm-sort-btn[data-col-filter]'), function (btn) {
				var key = btn.getAttribute('data-col-filter');
				var val = '';
				if (state.filtre && Object.prototype.hasOwnProperty.call(state.filtre, key))
					val = state.filtre[key] || '';
				else if (keys && keys.indexOf(key) >= 0)
					val = state[key] || '';
				var on = !!val;
				btn.classList.toggle('is-filtered', on);
				btn.setAttribute('aria-expanded', 'false');
				var caret = btn.querySelector('.crm-filter-caret');
				if (caret)
					caret.classList.toggle('is-on', on);
			});
		}
	};
})(window);

(function () {
	'use strict';

	/* ── Auth: Sidebar kullanıcı adını doldur + Logout ──────────────────── */
	(function initAuthUI() {
		function kullaniciAdiniYaz() {
			var user = window.Auth && window.Auth.getUser ? window.Auth.getUser() : null;
			var ad = (user && (user.ad_soyad || user.kullanici_adi)) || '—';
			var kadi = (user && user.kullanici_adi) || '—';
			var nameEl = document.getElementById('crm-nav-user-name');
			var kadiEl = document.getElementById('crm-nav-user-kadi');
			var labelEl = document.querySelector('.crm-nav-user-label');
			if (nameEl) nameEl.textContent = ad;
			if (kadiEl) kadiEl.textContent = '@' + kadi;
			if (labelEl) labelEl.textContent = 'Giriş yapıldı';
		}
		function rolNavUygula() {
			var isAdmin = window.Auth && window.Auth.isAdmin && window.Auth.isAdmin();
			document.body.classList.toggle('crm-is-admin', !!isAdmin);
			var navKullanici = document.getElementById('nav-li-kullanici-yonetimi');
			var navUrunler = document.getElementById('nav-li-urunler');
			if (navKullanici) navKullanici.hidden = !isAdmin;
			if (navUrunler) navUrunler.hidden = !isAdmin;
			if (!isAdmin) {
				var hash = (window.location.hash || '').replace('#', '').trim();
				if (hash === 'kullanici-yonetimi' || hash === 'urunler') {
					if (typeof window.crmSekmeyiAc === 'function')
						window.crmSekmeyiAc('gorusmeler');
				}
			}
		}
		kullaniciAdiniYaz();
		rolNavUygula();
		window.crmNavKullaniciGuncelle = kullaniciAdiniYaz;
		if (window.Auth && typeof window.Auth.refreshUser === 'function') {
			window.Auth.refreshUser().then(function () {
				kullaniciAdiniYaz();
				rolNavUygula();
				if (typeof window.crmTodosYenile === 'function')
					window.crmTodosYenile();
				if (typeof window.crmNavRozetleriGuncelle === 'function')
					window.crmNavRozetleriGuncelle();
				if (typeof window.yoneticiNotlariniYukle === 'function')
					window.yoneticiNotlariniYukle();
			}).catch(function () {});
		}
		var cikisBtn = document.getElementById('btn-cikis');
		if (cikisBtn) {
			cikisBtn.addEventListener('click', function () {
				if (window.Auth) window.Auth.logout();
			});
		}

		var sifreBtn = document.getElementById('btn-sifre-degistir');
		var profilBtn = document.getElementById('btn-profil-duzenle');
		var profilModal = document.getElementById('profil-modal');
		var profilForm = document.getElementById('profil-form');
		var profilKadiEl = document.getElementById('profil-kullanici-adi');
		var profilAdEl = document.getElementById('profil-ad-soyad');
		var profilHataEl = document.getElementById('profil-form-hata');

		function profilModalAc() {
			var user = window.Auth && window.Auth.getUser ? window.Auth.getUser() : null;
			if (profilKadiEl) profilKadiEl.value = (user && user.kullanici_adi) || '';
			if (profilAdEl) profilAdEl.value = (user && user.ad_soyad) || '';
			if (profilHataEl) profilHataEl.hidden = true;
			if (profilModal) profilModal.hidden = false;
			if (profilAdEl) profilAdEl.focus();
		}

		function profilModalKapat() {
			if (profilModal) profilModal.hidden = true;
		}

		if (profilBtn) profilBtn.addEventListener('click', profilModalAc);
		var profilModalKapatBtn = document.getElementById('profil-modal-kapat');
		var profilFormIptal = document.getElementById('profil-form-iptal');
		if (profilModalKapatBtn) profilModalKapatBtn.addEventListener('click', profilModalKapat);
		if (profilFormIptal) profilFormIptal.addEventListener('click', profilModalKapat);
		if (profilModal) {
			profilModal.addEventListener('click', function (e) {
				if (e.target && e.target.getAttribute('data-close-profil-modal') !== null)
					profilModalKapat();
			});
		}
		if (profilForm) {
			profilForm.addEventListener('submit', function (e) {
				e.preventDefault();
				var ad = (profilAdEl && profilAdEl.value) || '';
				if (!String(ad).trim()) {
					if (profilHataEl) {
						profilHataEl.textContent = 'Ad soyad zorunludur.';
						profilHataEl.hidden = false;
					}
					return;
				}
				if (!window.Auth || typeof window.Auth.updateProfile !== 'function') {
					if (profilHataEl) {
						profilHataEl.textContent = 'Profil güncelleme kullanılamıyor.';
						profilHataEl.hidden = false;
					}
					return;
				}
				window.Auth.updateProfile(String(ad).trim())
					.then(function () {
						profilModalKapat();
						if (typeof window.crmNavKullaniciGuncelle === 'function')
							window.crmNavKullaniciGuncelle();
						if (typeof window.gosterToast === 'function')
							window.gosterToast('Profiliniz güncellendi', 'ok');
					})
					.catch(function (err) {
						if (profilHataEl) {
							profilHataEl.textContent = (err && err.message) || 'Profil güncellenemedi';
							profilHataEl.hidden = false;
						}
					});
			});
		}

		var sifreModal = document.getElementById('sifre-modal');
		var sifreForm = document.getElementById('sifre-degistir-form');
		var sifreKadiEl = document.getElementById('sifre-kullanici-adi');
		var sifreMevcutEl = document.getElementById('sifre-mevcut');
		var sifreYeniEl = document.getElementById('sifre-yeni');
		var sifreYeniTekrarEl = document.getElementById('sifre-yeni-tekrar');
		var sifreHataEl = document.getElementById('sifre-form-hata');

		function sifreModalAc() {
			var user = window.Auth && window.Auth.getUser ? window.Auth.getUser() : null;
			if (sifreKadiEl) sifreKadiEl.value = (user && user.kullanici_adi) || '';
			if (sifreMevcutEl) sifreMevcutEl.value = '';
			if (sifreYeniEl) sifreYeniEl.value = '';
			if (sifreYeniTekrarEl) sifreYeniTekrarEl.value = '';
			if (sifreHataEl) sifreHataEl.hidden = true;
			if (sifreModal) sifreModal.hidden = false;
			if (sifreMevcutEl) sifreMevcutEl.focus();
		}

		function sifreModalKapat() {
			if (sifreModal) sifreModal.hidden = true;
		}

		if (sifreBtn) sifreBtn.addEventListener('click', sifreModalAc);
		var sifreModalKapatBtn = document.getElementById('sifre-modal-kapat');
		var sifreFormIptal = document.getElementById('sifre-form-iptal');
		if (sifreModalKapatBtn) sifreModalKapatBtn.addEventListener('click', sifreModalKapat);
		if (sifreFormIptal) sifreFormIptal.addEventListener('click', sifreModalKapat);
		if (sifreModal) {
			sifreModal.addEventListener('click', function (e) {
				if (e.target && e.target.getAttribute('data-close-sifre-modal') !== null)
					sifreModalKapat();
			});
		}
		if (sifreForm) {
			sifreForm.addEventListener('submit', function (e) {
				e.preventDefault();
				var mevcut = (sifreMevcutEl && sifreMevcutEl.value) || '';
				var yeni = (sifreYeniEl && sifreYeniEl.value) || '';
				var tekrar = (sifreYeniTekrarEl && sifreYeniTekrarEl.value) || '';
				if (!mevcut || !yeni) {
					if (sifreHataEl) { sifreHataEl.textContent = 'Tüm alanları doldurun.'; sifreHataEl.hidden = false; }
					return;
				}
				if (yeni.length < 4) {
					if (sifreHataEl) { sifreHataEl.textContent = 'Yeni şifre en az 4 karakter olmalıdır.'; sifreHataEl.hidden = false; }
					return;
				}
				if (yeni !== tekrar) {
					if (sifreHataEl) { sifreHataEl.textContent = 'Yeni şifreler eşleşmiyor.'; sifreHataEl.hidden = false; }
					return;
				}
				if (!window.Auth || typeof window.Auth.changePassword !== 'function') {
					if (sifreHataEl) { sifreHataEl.textContent = 'Şifre güncelleme kullanılamıyor.'; sifreHataEl.hidden = false; }
					return;
				}
				window.Auth.changePassword(mevcut, yeni)
					.then(function (data) {
						if (data && data.access_token && typeof window.Auth.setToken === 'function')
							window.Auth.setToken(data.access_token);
						sifreModalKapat();
						if (typeof window.gosterToast === 'function')
							window.gosterToast('Şifreniz güncellendi', 'ok');
					})
					.catch(function (err) {
						if (sifreHataEl) {
							sifreHataEl.textContent = (err && err.message) || 'Şifre güncellenemedi';
							sifreHataEl.hidden = false;
						}
					});
			});
		}
	})();
	/* ───────────────────────────────────────────────────────────────────── */

	var API_URL = CRM_API + '/api/analiz';
	var STATS_URL = CRM_API + '/api/istatistikler';
	var DETAY_URL = CRM_API + '/api/kurum-detay';
	var TODO_KEY = 'crm-todo-items';
	var SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
	var GECERSIZ_YANIT = 'Sunucudan geçersiz veya boş yanıt alındı';

	var globalStats = null;
	var lastAnalysis = null;
	var modalMode = 'list';
	var statsModal = document.getElementById('stats-modal');
	var statsModalTitle = document.getElementById('stats-modal-title');
	var statsModalList = document.getElementById('stats-modal-liste');
	var statsModalListWrap = document.getElementById('stats-modal-liste-wrap');
	var statsModalDetay = document.getElementById('stats-modal-detay');
	var statsModalClose = document.getElementById('stats-modal-kapat');
	var statsModalBack = document.getElementById('stats-modal-geri');
	var detayYukle = document.getElementById('detay-yukleniyor');
	var detayHata = document.getElementById('detay-hata');
	var detayHataMetni = document.getElementById('detay-hata-metni');
	var detayIcerik = document.getElementById('detay-icerik');
	var detayTarih = document.getElementById('detay-tarih');
	var detayDurum = document.getElementById('detay-durum');
	var detaySurec = document.getElementById('detay-surec');
	var detayUrunler = document.getElementById('detay-urunler');
	var detayNot = document.getElementById('detay-not');
	var detayGorevlerList = document.getElementById('detay-gorevler-list');
	var detayGorevlerBos = document.getElementById('detay-gorevler-bos');
	var detayDurumField = detayDurum ? detayDurum.parentNode : null;

	function hataMesajiniAl(data, status) {
		var msg = data && (data.detail || data.hata || data.detay || data.message);
		if (Array.isArray(msg))
			msg = msg.map(function (x) { return (x && x.msg) || String(x); }).join(' ');
		if (msg && typeof msg === 'object')
			msg = JSON.stringify(msg);
		return (msg && String(msg).trim()) || ('HTTP ' + (status || ''));
	}

	function jsonGuvenliParse(raw) {
		var text = raw == null ? '' : String(raw).trim();
		if (!text)
			throw new Error(GECERSIZ_YANIT);
		var ilk = text.charAt(0);
		if (ilk !== '{' && ilk !== '[')
			throw new Error(GECERSIZ_YANIT);
		try {
			return JSON.parse(text);
		} catch (err) {
			throw new Error(GECERSIZ_YANIT);
		}
	}

	function fetchJson(url, options) {
		return fetch(url, options).then(function (response) {
			return response.text().then(function (raw) {
				var data;
				try {
					data = jsonGuvenliParse(raw);
				} catch (err) {
					if (!response.ok)
						throw new Error('Sunucu hatası (HTTP ' + response.status + ').');
					throw err;
				}
				if (!response.ok)
					throw new Error(hataMesajiniAl(data, response.status));
				return data;
			});
		});
	}

	window.jsonGuvenliParse = jsonGuvenliParse;
	window.hataMesajiniAl = hataMesajiniAl;
	window.fetchJson = fetchJson;

	function gosterToast(mesaj, tip) {
		var stack = document.getElementById('crm-toast-stack');
		var el;
		if (!stack || !mesaj)
			return;
		el = document.createElement('div');
		el.className = 'crm-toast' + (tip === 'hata' ? ' is-hata' : (tip === 'ok' ? ' is-ok' : ''));
		el.setAttribute('role', 'status');
		el.textContent = String(mesaj);
		stack.appendChild(el);
		window.setTimeout(function () {
			if (el.parentNode)
				el.parentNode.removeChild(el);
		}, 4200);
	}

	window.gosterToast = gosterToast;

	function fillGlobalStats(stats) {
		var kurumEl = document.getElementById('stat-kurum');
		var urunEl = document.getElementById('stat-urun');
		var gorusmeEl = document.getElementById('stat-gorusme');
		var gorevEl = document.getElementById('stat-gorev');
		var data = stats && typeof stats === 'object' ? stats : null;
		var son, parcalar;

		globalStats = data;

		if (!data) {
			if (kurumEl) kurumEl.textContent = '—';
			if (urunEl) urunEl.textContent = '—';
			if (gorusmeEl) gorusmeEl.textContent = '—';
			if (gorevEl) gorevEl.textContent = '—';
			var navBos = document.getElementById('nav-son-gorusme-ad');
			if (navBos) navBos.textContent = '—';
			return;
		}

		if (kurumEl)
			kurumEl.textContent = data.analiz_sayisi != null
				? (data.analiz_sayisi + ' Görüşme')
				: (data.toplam_kurum_sayisi != null ? (data.toplam_kurum_sayisi + ' Kurum') : '—');

		if (urunEl) {
			if (data.populer_urun_sayisi != null)
				urunEl.textContent = data.populer_urun_sayisi + ' Ürün';
			else if (data.urun_listesi && data.urun_listesi.length)
				urunEl.textContent = data.urun_listesi[0];
			else
				urunEl.textContent = '—';
		}

		if (gorusmeEl) {
			son = data.son_gorusme || null;
			parcalar = [];
			if (son && son.tarih)
				parcalar.push(formatDisplayDate(son.tarih));
			if (son && son.kurum_adi)
				parcalar.push(son.kurum_adi);
			if (parcalar.length)
				gorusmeEl.textContent = parcalar.join(' · ');
			else if (data.not_sayisi)
				gorusmeEl.textContent = data.not_sayisi + ' kayıtlı not';
			else
				gorusmeEl.textContent = 'Kayıt yok';
		}

		if (gorevEl) {
			gorevEl.textContent = data.aktif_gorev_sayisi != null
				? (data.aktif_gorev_sayisi + ' Görev')
				: '—';
		}

		var navSon = document.getElementById('nav-son-gorusme-ad');
		if (navSon) {
			son = data && data.son_gorusme;
			navSon.textContent = (son && son.kurum_adi) ? son.kurum_adi : 'Kayıt yok';
		}
	}

	function loadGlobalStats() {
		fillGlobalStats(null);
		var kurumEl = document.getElementById('stat-kurum');
		var urunEl = document.getElementById('stat-urun');
		var gorusmeEl = document.getElementById('stat-gorusme');
		var gorevEl = document.getElementById('stat-gorev');

		if (kurumEl) kurumEl.textContent = 'Veri bekleniyor...';
		if (urunEl) urunEl.textContent = 'Veri bekleniyor...';
		if (gorusmeEl) gorusmeEl.textContent = 'Veri bekleniyor...';
		if (gorevEl) gorevEl.textContent = 'Veri bekleniyor...';

		fetchJson(STATS_URL, {
			method: 'GET',
			headers: { 'Accept': 'application/json' }
		})
			.then(fillGlobalStats)
			.catch(function () {
				fillGlobalStats(null);
			});
	}

	function normalizeKurumItem(item) {
		if (item && typeof item === 'object')
			return { id: item.id || item.kurum_id || null, name: item.name || item.kurum_adi || '' };
		return { id: null, name: String(item || '') };
	}

	function showModalList() {
		modalMode = 'list';
		if (statsModalListWrap) statsModalListWrap.hidden = false;
		if (statsModalDetay) statsModalDetay.hidden = true;
		if (statsModalBack) statsModalBack.hidden = true;
	}

	function showModalDetay() {
		modalMode = 'detay';
		if (statsModalListWrap) statsModalListWrap.hidden = true;
		if (statsModalDetay) statsModalDetay.hidden = false;
		if (statsModalBack) statsModalBack.hidden = false;
	}

	function closeStatsModal() {
		if (!statsModal)
			return;
		statsModal.hidden = true;
		showModalList();
	}

	function formatDisplayDate(value) {
		if (!value)
			return '—';
		var text = String(value);
		var date = new Date(text);
		if (!isNaN(date.getTime()) && /^\d{4}-\d{2}-\d{2}/.test(text))
			return date.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric' });
		return text;
	}

	function applyDurumTone(el, label) {
		var cls = 'is-pending';
		var text = String(label || '').toLocaleLowerCase('tr-TR');
		if (/karma|mixed/.test(text))
			cls = 'is-karma';
		else if (/olumlu|pozitif|aktif|onay|success/.test(text))
			cls = 'is-positive';
		else if (/olumsuz|negatif|red|iptal/.test(text))
			cls = 'is-negative';
		if (el) {
			el.classList.remove('is-positive', 'is-negative', 'is-pending', 'is-karma');
			el.classList.add(cls);
		}
	}

	function surecTipiSec(deger) {
		var d = String(deger || '').toLowerCase();
		if (/deneme|demo|trial|pilot/.test(d)) return 'Deneme';
		if (/abone|sat[iı]n|lisans|kontrat|s[oö]zle[sş]me/.test(d)) return 'Abonelik';
		return 'Hiçbiri';
	}

	function surecTipiSinif(deger) {
		var v = surecTipiSec(deger);
		if (v === 'Deneme') return 'is-deneme';
		if (v === 'Abonelik') return 'is-abonelik';
		return 'is-hicbiri';
	}

	function renderKurumDetay(data) {
		var urunler = data && data.ilgilenilen_urunler;
		var durum = (data && (data.gorusme_durumu || data.durum)) || '—';
		var surec = surecTipiSec(data && (data.surec_tipi || data.abonelik_tipi));

		if (detayYukle) detayYukle.hidden = true;
		if (detayHata) detayHata.hidden = true;
		if (detayIcerik) detayIcerik.hidden = false;

		if (statsModalTitle)
			statsModalTitle.textContent = (data && (data.kurum_adi || data.name)) || 'Kurum detayı';
		if (detayTarih)
			detayTarih.textContent = formatDisplayDate(data && (data.son_gorusme_tarihi || data.updated_at));
		if (detayDurum)
			detayDurum.textContent = durum;
		applyDurumTone(detayDurumField, durum);
		if (detaySurec) {
			detaySurec.innerHTML = '';
			detaySurec.classList.add('crm-chip-row');
			var surecChip = document.createElement('span');
			surecChip.className = 'crm-chip crm-chip-subscription ' + surecTipiSinif(surec);
			surecChip.textContent = surec;
			detaySurec.appendChild(surecChip);
		}
		if (detayUrunler) {
			detayUrunler.innerHTML = '';
			if (Array.isArray(urunler) && urunler.length) {
				detayUrunler.classList.add('crm-chip-row');
				urunler.forEach(function (ad) {
					if (!ad) return;
					var chip = document.createElement('span');
					chip.className = 'crm-chip crm-chip-product';
					chip.textContent = ad;
					detayUrunler.appendChild(chip);
				});
			} else if (data && (data.urun_adi || data.urun_kodu)) {
				detayUrunler.classList.add('crm-chip-row');
				var tek = document.createElement('span');
				tek.className = 'crm-chip crm-chip-product';
				tek.textContent = data.urun_adi || data.urun_kodu;
				detayUrunler.appendChild(tek);
			} else {
				detayUrunler.classList.remove('crm-chip-row');
				detayUrunler.textContent = '—';
			}
		}
		if (detayNot)
			detayNot.textContent = (data && (data.gecmis_not || data.not_icerigi)) || 'Kayıtlı görüşme notu yok.';
		renderKurumDetayGorevleri(data && data.gorevler);
	}

	function gorevBasligiAl(g) {
		if (!g) return '';
		if (typeof g === 'string') return g.trim();
		return String(g.baslik || g.task || g.title || '').trim();
	}

	function renderKurumDetayGorevleri(gorevler) {
		if (!detayGorevlerList)
			return;
		var gecerli = (Array.isArray(gorevler) ? gorevler : []).filter(function (g) {
			if (!gorevBasligiAl(g))
				return false;
			var kaynak = String((g && (g.kaynak || g.source)) || 'ai').toLowerCase();
			return kaynak !== 'manuel' && kaynak !== 'manual';
		});
		detayGorevlerList.innerHTML = '';
		if (!gecerli.length) {
			if (detayGorevlerBos) detayGorevlerBos.hidden = false;
			return;
		}
		if (detayGorevlerBos) detayGorevlerBos.hidden = true;
		gecerli.forEach(function (g) {
			var li = document.createElement('li');
			var ikon = document.createElement('span');
			var title = document.createElement('span');
			var done = !!(g && g.tamamlandi);
			li.className = 'crm-gorev-item' + (done ? ' is-done' : '');
			ikon.className = 'crm-gorev-check' + (done ? ' is-on' : '');
			ikon.setAttribute('aria-hidden', 'true');
			ikon.innerHTML = '<span class="icon solid fa-check"></span>';
			title.className = 'crm-gorev-title';
			title.textContent = gorevBasligiAl(g);
			li.appendChild(ikon);
			li.appendChild(title);
			detayGorevlerList.appendChild(li);
		});
	}

	function openKurumDetay(item) {
		if (typeof window.crmDrawerKurumAc === 'function') {
			window.crmDrawerKurumAc({
				kurum_id: item && (item.kurum_id || item.id) || null,
				name: item && (item.name || item.kurum_adi) || ''
			});
			return;
		}
		var kurum = normalizeKurumItem(item);
		var query;

		if (!kurum.name && !kurum.id)
			return;

		if (statsModal) statsModal.hidden = false;
		showModalDetay();
		if (statsModalTitle) statsModalTitle.textContent = kurum.name || 'Kurum detayı';
		if (detayIcerik) detayIcerik.hidden = true;
		if (detayHata) detayHata.hidden = true;
		if (detayYukle) detayYukle.hidden = false;

		query = kurum.id
			? ('id=' + encodeURIComponent(kurum.id))
			: ('ad=' + encodeURIComponent(kurum.name));

		fetchJson(DETAY_URL + '?' + query, { headers: { 'Accept': 'application/json' } })
			.then(renderKurumDetay)
			.catch(function () {
				var payload = lastAnalysis && typeof lastAnalysis === 'object' ? lastAnalysis : null;
				var analizAdi = payload && (payload.kurum_adi || payload.kurumAdi);

				if (payload && analizAdi && kurum.name && analizAdi.toLocaleLowerCase('tr-TR') === kurum.name.toLocaleLowerCase('tr-TR')) {
					renderKurumDetay({
						kurum_adi: analizAdi,
						son_gorusme_tarihi: payload.baslangic_tarihi || payload.gelecek_gorusme_tarihi,
						ilgilenilen_urunler: payload.ilgilenilen_urunler || (payload.urun_adi ? [payload.urun_adi] : (payload.urun_kodu ? [payload.urun_kodu] : [])),
						surec_tipi: payload.surec_tipi || payload.abonelik_tipi,
						gorusme_durumu: payload.durum || payload.gorusme_durumu || 'Beklemede',
						gecmis_not: payload.not_icerigi || payload.aksiyon_adimi || '',
						gorevler: payload.gorevler || []
					});
					return;
				}

				if (detayYukle) detayYukle.hidden = true;
				if (detayIcerik) detayIcerik.hidden = true;
				if (detayHata) detayHata.hidden = false;
				if (detayHataMetni) detayHataMetni.textContent = 'Kurum detayı alınamadı. Kayıt veritabanında yok olabilir.';
			});
	}

	function openStatsModal(title, items, clickable) {
		var i, li, item, kurum;

		if (!statsModal || !statsModalTitle || !statsModalList)
			return;

		showModalList();
		statsModalTitle.textContent = title;
		statsModalList.innerHTML = '';

		if (!items || !items.length) {
			li = document.createElement('li');
			li.textContent = globalStats ? 'Kayıt bulunamadı.' : 'Veri bekleniyor...';
			statsModalList.appendChild(li);
		} else {
			for (i = 0; i < items.length; i++) {
				item = items[i];
				li = document.createElement('li');
				if (clickable) {
					kurum = normalizeKurumItem(item);
					li.className = 'is-clickable';
					li.textContent = kurum.name;
					li.setAttribute('tabindex', '0');
					li.addEventListener('click', function (secili) {
						return function () { openKurumDetay(secili); };
					}(kurum));
					li.addEventListener('keydown', function (secili) {
						return function (event) {
							if (event.key === 'Enter' || event.key === ' ') {
								event.preventDefault();
								openKurumDetay(secili);
							}
						};
					}(kurum));
				} else {
					li.textContent = typeof item === 'object' ? (item.name || item.kod || JSON.stringify(item)) : String(item);
				}
				statsModalList.appendChild(li);
			}
		}

		statsModal.hidden = false;
	}

	function onStatCardActivate(listKey, retried) {
		if (!globalStats) {
			if (retried) {
				openStatsModal(listKey === 'urun' ? 'Ürün listesi' : 'Kurum listesi', [], listKey !== 'urun');
				return;
			}
			fetchJson(STATS_URL, { method: 'GET', headers: { 'Accept': 'application/json' } })
				.then(function (data) {
					fillGlobalStats(data);
					onStatCardActivate(listKey, true);
				})
				.catch(function () {
					openStatsModal(listKey === 'urun' ? 'Ürün listesi' : 'Kurum listesi', [], listKey !== 'urun');
				});
			return;
		}

		if (listKey === 'kurum') {
			if (typeof window.crmSekmeyiAc === 'function') {
				window.crmSekmeyiAc('kurumlar');
				return;
			}
			openStatsModal('Kurum listesi', globalStats.kurum_listesi || [], true);
			return;
		}

		if (listKey === 'urun') {
			if (window.Auth && window.Auth.isAdmin && window.Auth.isAdmin() &&
				typeof window.crmSekmeyiAc === 'function') {
				window.crmSekmeyiAc('urunler');
				return;
			}
			openStatsModal('Ürün listesi', globalStats.urun_listesi || [], false);
			return;
		}

		if (listKey === 'gorusme') {
			var son = globalStats.son_gorusme;
			if (son && (son.kurum_id || son.kurum_adi)) {
				openKurumDetay({ id: son.kurum_id, name: son.kurum_adi });
				return;
			}
			openStatsModal('Kurum listesi', globalStats.kurum_listesi || [], true);
		}
	}

	function bindStatCards() {
		var statsBar = document.getElementById('global-stats');
		if (statsBar && !statsBar.getAttribute('data-bound')) {
			statsBar.setAttribute('data-bound', '1');
			statsBar.addEventListener('click', function (event) {
				var card = event.target.closest ? event.target.closest('.crm-stat.is-clickable') : null;
				if (!card || !statsBar.contains(card))
					return;
				event.preventDefault();
				var viewLink = card.getAttribute('data-view-link');
				if (viewLink && typeof window.crmSekmeyiAc === 'function') {
					window.crmSekmeyiAc(viewLink);
					return;
				}
				onStatCardActivate(card.getAttribute('data-list'));
			});
			statsBar.addEventListener('keydown', function (event) {
				if (event.key !== 'Enter' && event.key !== ' ')
					return;
				var card = event.target.closest ? event.target.closest('.crm-stat.is-clickable') : null;
				if (!card)
					return;
				event.preventDefault();
				var viewLink = card.getAttribute('data-view-link');
				if (viewLink && typeof window.crmSekmeyiAc === 'function') {
					window.crmSekmeyiAc(viewLink);
					return;
				}
				onStatCardActivate(card.getAttribute('data-list'));
			});
		}
	}

	bindStatCards();

	var navSonKart = document.getElementById('nav-son-gorusme');
	if (navSonKart && !navSonKart.getAttribute('data-bound')) {
		navSonKart.setAttribute('data-bound', '1');
		navSonKart.addEventListener('click', function () {
			onStatCardActivate('gorusme');
		});
		navSonKart.addEventListener('keydown', function (event) {
			if (event.key === 'Enter' || event.key === ' ') {
				event.preventDefault();
				onStatCardActivate('gorusme');
			}
		});
	}

	if (statsModalClose)
		statsModalClose.addEventListener('click', closeStatsModal);

	if (statsModalBack)
		statsModalBack.addEventListener('click', function () {
			openStatsModal('Kurum listesi', globalStats && globalStats.kurum_listesi ? globalStats.kurum_listesi : [], true);
		});

	if (statsModal) {
		statsModal.addEventListener('click', function (event) {
			if (event.target === statsModal || event.target.getAttribute('data-close-modal') !== null)
				closeStatsModal();
		});
	}

	var kartKurumOzet = document.getElementById('kart-kurum');
	if (kartKurumOzet) {
		kartKurumOzet.addEventListener('click', function () {
			var adEl = document.getElementById('ozet-kurum');
			var ad = adEl ? adEl.textContent.trim() : '';
			if (!ad || ad === '—')
				return;
			openKurumDetay({ name: ad });
		});
	}

	document.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && statsModal && !statsModal.hidden)
			closeStatsModal();
	});

	if (document.readyState === 'loading')
		document.addEventListener('DOMContentLoaded', loadGlobalStats);
	else
		loadGlobalStats();

	var form = document.getElementById('analiz-formu');
	var textarea = document.getElementById('gorusme-metni');
	var btnSes = document.getElementById('btn-ses');
	var btnAnalyze = document.getElementById('btn-analiz-et') || document.getElementById('btn-analiz');
	var btnCopy = document.getElementById('btn-json-kopyala');
	var statusEl = document.getElementById('ses-durumu');
	var loadingEl = document.getElementById('analiz-yukleniyor');
	var errorBox = document.getElementById('analiz-hata');
	var errorText = document.getElementById('analiz-hata-metni');
	var resultBox = document.getElementById('analiz-sonuc');
	var resultCode = document.getElementById('analiz-json');
	var summaryBox = document.getElementById('analiz-ozet');
	var kartDurum = document.getElementById('kart-durum');
	var todoForm = document.getElementById('todo-form');
	var todoBaslik = document.getElementById('todo-baslik');
	var todoTarih = document.getElementById('todo-tarih');
	var todoList = document.getElementById('todo-list');
	var todoDoneList = document.getElementById('todo-done-list');
	var todoDoneWrap = document.getElementById('todo-done-wrap');
	var todos = [];
	var TODO_DONE_TTL_MS = 14 * 24 * 60 * 60 * 1000;
	var gorevSorgu = { q: '', durum: 'aktif', sort: 'due-asc' };

	if (!form || !textarea || !btnSes)
		console.warn('CRM: form veya mikrofon butonu eksik');

	var recognition = null;
	var isRecording = false;
	var baseText = '';
	var frozenSpeech = '';
	var speechRestarting = false;

	function show(el) {
		if (el)
			el.hidden = false;
	}

	function hide(el) {
		if (el)
			el.hidden = true;
	}

	var SES_HAZIR = 'Konuşmak için basın. Durdurunca not analiz edilir.';

	function setStatus(message, listening) {
		if (!statusEl)
			return;

		statusEl.hidden = false;
		if (!message) {
			statusEl.textContent = SES_HAZIR;
			statusEl.classList.remove('is-listening');
			return;
		}

		statusEl.textContent = message;
		statusEl.classList.toggle('is-listening', !!listening);
	}

	function showError(message) {
		if (!errorBox || !errorText)
			return;

		errorText.textContent = message;
		show(errorBox);
		errorBox.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
	}

	function hideError() {
		hide(errorBox);
		if (errorText)
			errorText.textContent = '';
	}

	function setText(id, value, empty) {
		var el = document.getElementById(id);
		if (!el)
			return;
		if (value == null || String(value).trim() === '')
			el.textContent = empty == null ? '—' : empty;
		else
			el.textContent = String(value);
	}

	function unwrapPayload(data) {
		if (!data || typeof data !== 'object')
			return {};
		if (data.ai_ciktisi && typeof data.ai_ciktisi === 'object')
			return data.ai_ciktisi;
		if (data.analiz && typeof data.analiz === 'object')
			return data.analiz;
		return data;
	}

	function pick(source, keys) {
		var i, key, nested;
		if (!source || typeof source !== 'object')
			return '';

		for (i = 0; i < keys.length; i++) {
			key = keys[i];
			if (source[key] != null && String(source[key]).trim() !== '')
				return source[key];
		}

		nested = unwrapPayload(source);
		if (nested !== source) {
			for (i = 0; i < keys.length; i++) {
				key = keys[i];
				if (nested[key] != null && String(nested[key]).trim() !== '')
					return nested[key];
			}
		}

		return '';
	}

	function classifyStatus(raw) {
		var text = String(raw || '').toLocaleLowerCase('tr-TR');

		if (/karma|mixed/.test(text))
			return { label: raw || 'Karma', tone: 'karma', hint: 'Karışık geri bildirim' };

		if (/olumlu|pozitif|başarılı|basarili|aktif|onay|closed.?won|success|positive/.test(text))
			return { label: raw || 'Olumlu', tone: 'positive', hint: 'İlerleme olumlu' };

		if (/olumsuz|negatif|red|iptal|kay[ıi]p|closed.?lost|negative|reject/.test(text))
			return { label: raw || 'Olumsuz', tone: 'negative', hint: 'Risk / olumsuz' };

		if (/bekle|pending|incele|talep|sözleşme|sozlesme|bütçe|butce|wait/.test(text))
			return { label: raw || 'Beklemede', tone: 'pending', hint: 'Aksiyon bekleniyor' };

		if (!raw)
			return { label: 'Beklemede', tone: 'pending', hint: 'Durum belirtilmedi' };

		return { label: raw, tone: 'pending', hint: '' };
	}

	function fillGlance(data) {
		var payload = unwrapPayload(data);
		var kurum = pick(payload, ['kurum_adi', 'kurumAdi', 'eklenen_kurum', 'musteri']) || pick(data, ['eklenen_kurum', 'kurum_adi']);
		var urun = '';
		if (payload && Array.isArray(payload.ilgilenilen_urunler) && payload.ilgilenilen_urunler.length)
			urun = payload.ilgilenilen_urunler.filter(Boolean).join(', ');
		if (!urun)
			urun = pick(payload, ['urun_adi', 'urun_kodu', 'urun', 'urunler', 'konu']);
		var surecTipi = pick(payload, ['surec_tipi', 'abonelik_tipi']);
		var durumRaw = pick(payload, ['durum', 'status', 'genel_durum']) || pick(data, ['durum', 'mesaj']);
		var durum = classifyStatus(durumRaw);

		setText('ozet-durum', durum.label);
		setText('ozet-durum-alt', [kurum, urun, surecTipi, durum.hint].filter(Boolean).join(' · ') || durum.hint, '');

		if (kartDurum) {
			kartDurum.classList.remove('is-positive', 'is-negative', 'is-pending', 'is-karma');
			kartDurum.classList.add('is-' + durum.tone);
		}

		show(summaryBox);
		lastAnalysis = data;
		var analizId = payload && (payload.analiz_id || payload.id);
		if (!analizId && data)
			analizId = data.analiz_id || data.id;
		if (kartDurum) {
			if (analizId)
				kartDurum.setAttribute('data-analiz-id', String(analizId));
			else
				kartDurum.removeAttribute('data-analiz-id');
		}
	}

	function ozetKartindanDetayAc() {
		var id = kartDurum && kartDurum.getAttribute('data-analiz-id');
		if (!id && lastAnalysis)
			id = lastAnalysis.analiz_id || lastAnalysis.id || (lastAnalysis.kayit && lastAnalysis.kayit.id);
		if (id && typeof window.crmKayitDetayiniAc === 'function') {
			window.crmKayitDetayiniAc(id);
			return true;
		}
		return false;
	}

	if (kartDurum) {
		kartDurum.addEventListener('click', ozetKartindanDetayAc);
		kartDurum.addEventListener('keydown', function (e) {
			if (e.key === 'Enter' || e.key === ' ') {
				e.preventDefault();
				ozetKartindanDetayAc();
			}
		});
	}

	window.fillGlance = fillGlance;
	window.loadGlobalStats = loadGlobalStats;

	function loadTodos() {
		try {
			todos = JSON.parse(localStorage.getItem(TODO_KEY) || '[]');
			if (!Array.isArray(todos))
				todos = [];
			todos = todos.filter(function (item) {
				var title = item && typeof item.title === 'string' ? item.title.trim() : '';
				if (!title)
					return false;
				/* Sunucuya kayıtlı / manuel görevleri kelime limitiyle düşürme */
				if (item.dbId || item.source === 'manual' || item.source === 'manuel')
					return true;
				return title.split(/\s+/).length <= 20;
			});
			todos.forEach(function (item) {
				if (item.done && !item.doneAt)
					item.doneAt = item.createdAt || new Date().toISOString();
			});
		} catch (err) {
			todos = [];
		}
		purgeExpiredTodos();
		renderTodos();
	}

	function purgeExpiredTodos() {
		var now = Date.now();
		var once = todos.length;
		todos = todos.filter(function (item) {
			if (!item.done)
				return true;
			var stamp = Date.parse(item.doneAt || item.createdAt || '');
			if (isNaN(stamp))
				return true;
			return (now - stamp) < TODO_DONE_TTL_MS;
		});
		if (todos.length !== once)
			saveTodos();
	}

	function saveTodos() {
		localStorage.setItem(TODO_KEY, JSON.stringify(todos));
	}

	function todoEmptyEl() {
		return document.getElementById('todo-empty');
	}

	function setTodoEmptyVisible(visible) {
		var emptyEl = todoEmptyEl();
		if (emptyEl)
			emptyEl.style.display = visible ? '' : 'none';
	}

	function isAdminGorevGorunumu() {
		return !!(window.Auth && window.Auth.isAdmin && window.Auth.isAdmin());
	}

	var TODO_KAPSAM_KEY = 'crm-todo-kapsam';
	var TODO_COMPOSER_KEY = 'crm-todo-composer';

	function gorevKapsamAl() {
		if (!isAdminGorevGorunumu())
			return '';
		try {
			var k = sessionStorage.getItem(TODO_KAPSAM_KEY) || 'benim';
			if (k === 'ekip_gorusmeleri' || k === 'benim')
				return k;
		} catch (e) {}
		return 'benim';
	}

	function gorevKapsamYaz(k) {
		try {
			sessionStorage.setItem(TODO_KAPSAM_KEY, k);
		} catch (e) {}
	}

	function gorevComposerAl() {
		try {
			var k = sessionStorage.getItem(TODO_COMPOSER_KEY) || 'kendime';
			if (k === 'personele' || k === 'kendime')
				return k;
		} catch (e) {}
		return 'kendime';
	}

	function gorevComposerYaz(k) {
		try {
			sessionStorage.setItem(TODO_COMPOSER_KEY, k);
		} catch (e) {}
	}

	function gorevComposerPanelleriniGuncelle() {
		var admin = isAdminGorevGorunumu();
		var ekip = admin && gorevKapsamAl() === 'ekip_gorusmeleri';
		var mod = gorevComposerAl();
		if (!admin)
			mod = 'kendime';
		var composer = document.getElementById('todo-composer');
		var todoTabs = document.getElementById('todo-composer-tabs');
		var dashTabs = document.getElementById('dash-composer-tabs');
		var kendimePanel = document.getElementById('todo-form-panel');
		var personelePanel = document.getElementById('todo-ata-panel');
		var dashKendime = document.getElementById('dash-hizli-gorev');
		var dashPersonele = document.getElementById('dash-personel-gorev');
		var todoForm = document.getElementById('todo-form');
		var gorevlerEkleBtn = document.getElementById('btn-gorevler-ekle');
		if (composer)
			composer.hidden = !!ekip;
		if (gorevlerEkleBtn)
			gorevlerEkleBtn.hidden = !!ekip;
		if (todoTabs)
			todoTabs.hidden = !admin || !!ekip;
		if (dashTabs)
			dashTabs.hidden = !admin;
		function tablariIsaretle(wrap) {
			if (!wrap)
				return;
			var butonlar = wrap.querySelectorAll('[data-composer]');
			var i;
			for (i = 0; i < butonlar.length; i++)
				butonlar[i].classList.toggle('is-active', butonlar[i].getAttribute('data-composer') === mod);
		}
		tablariIsaretle(todoTabs);
		tablariIsaretle(dashTabs);
		if (todoForm)
			todoForm.hidden = false;
		if (kendimePanel)
			kendimePanel.hidden = !!(ekip || (admin && mod === 'personele'));
		if (personelePanel)
			personelePanel.hidden = !admin || ekip || mod !== 'personele';
		if (dashKendime)
			dashKendime.hidden = !!(admin && mod === 'personele');
		if (dashPersonele)
			dashPersonele.hidden = !admin || mod !== 'personele';
	}

	function todoAciklamaGuncelle() {
		var p = document.getElementById('todo-aciklama');
		var form = document.getElementById('todo-form');
		var kapsam = gorevKapsamAl();
		var ekip = isAdminGorevGorunumu() && kapsam === 'ekip_gorusmeleri';
		if (p) {
			if (!isAdminGorevGorunumu())
				p.textContent = 'Yapılacaklarınız. Sarı kenarlı olanları yöneticiniz atadı. Görüşme notları Notlarım’dadır.';
			else if (ekip)
				p.textContent = 'Personel görüşmelerinden çıkan görevler. Varsayılan olarak görüşmeyi yapan kişidedir; Görev Ata ile aynı şirket içindeki birine verebilirsiniz.';
			else
				p.textContent = 'Yapılacaklar: atayın, tamamlayın, takip edin. Görüşme notları Notlarım’dadır.';
		}
		if (form)
			form.hidden = false;
	}

	function todoKapsamPaneliHazirla() {
		var wrap = document.getElementById('todo-kapsam');
		var admin = isAdminGorevGorunumu();
		var aktif = gorevKapsamAl() || 'benim';
		if (wrap)
			wrap.hidden = !admin;
		if (!wrap)
			return;
		var butonlar = wrap.querySelectorAll('[data-kapsam]');
		var i;
		for (i = 0; i < butonlar.length; i++)
			butonlar[i].classList.toggle('is-active', butonlar[i].getAttribute('data-kapsam') === aktif);
		todoAciklamaGuncelle();
		gorevComposerPanelleriniGuncelle();
	}

	function atananRenkSinifi(userId) {
		var n = parseInt(userId, 10);
		if (!n || isNaN(n))
			return '';
		return 'is-atanan-' + (Math.abs(n) % 6);
	}

	function mevcutKullaniciIdAl() {
		var me = window.Auth && window.Auth.getUser ? window.Auth.getUser() : null;
		return me && me.id != null ? parseInt(me.id, 10) : null;
	}

	function yoneticiAtamasiMi(info) {
		if (!info)
			return false;
		var atanan = parseInt(info.assigned_user_id || info.user_id, 10);
		var olusturan = parseInt(info.user_id, 10);
		if (!atanan || !olusturan)
			return false;
		return olusturan !== atanan;
	}

	function banaYoneticiAtamasiMi(info) {
		if (!yoneticiAtamasiMi(info))
			return false;
		var uid = mevcutKullaniciIdAl();
		if (!uid)
			return false;
		var atanan = parseInt(info.assigned_user_id || info.user_id, 10);
		return atanan === uid;
	}

	function createGorevLi(text, extra) {
		var li = document.createElement('li');
		var check = document.createElement('button');
		var body = document.createElement('div');
		var title = document.createElement('span');
		var meta = document.createElement('span');
		var info = extra || {};
		var done = !!info.done;
		var manuelMi = info.source === 'manual' || info.source === 'manuel';
		// Görüşme (AI) ile manuel görevleri her zaman rozet + sol çizgi ile ayırt et
		var etiketMetni = manuelMi ? 'Manuel' : 'Görüşme';

		li.className = 'crm-todo-item' + (manuelMi ? ' is-manuel' : ' is-ai');
		if (done)
			li.classList.add('is-done');
		if (info.id)
			li.dataset.id = info.id;
		if (info.dbId)
			li.dataset.dbId = String(info.dbId);
		if (info.company_id)
			li.dataset.companyId = String(info.company_id);
		li.dataset.source = manuelMi ? 'manual' : 'ai';

		var atananId = info.assigned_user_id || info.user_id;
		if (atananId)
			li.dataset.assignedUserId = String(atananId);
		var atananAd = (info.assigned_user_name || info.gorusme_sahibi_adi || '').trim();
		var banaAtandi = banaYoneticiAtamasiMi(info);
		if (banaAtandi)
			li.classList.add('is-yonetici-atama');
		if (isAdminGorevGorunumu() && atananId) {
			var renkSinifi = atananRenkSinifi(atananId);
			if (renkSinifi)
				li.classList.add(renkSinifi);
		}

		check.type = 'button';
		check.className = 'crm-todo-check' + (done ? ' is-on' : '');
		check.setAttribute('aria-pressed', done ? 'true' : 'false');
		check.setAttribute('aria-label', done ? 'Görevi geri al' : 'Görevi tamamla');
		check.innerHTML = '<span class="icon solid fa-check" aria-hidden="true"></span>';

		body.className = 'crm-todo-body';
		title.className = 'crm-todo-title';
		title.textContent = text;
		meta.className = 'crm-todo-meta';
		meta.textContent = done && info.doneAt
			? ('Tamamlandı · ' + formatDisplayDate(String(info.doneAt).slice(0, 10)))
			: formatDisplayDate(info.due || todayISO());

		li.appendChild(check);
		if (banaAtandi) {
			var yBanner = document.createElement('div');
			var olusturanAd = String(info.olusturan_adi || '').trim();
			yBanner.className = 'crm-todo-yonetici-banner';
			yBanner.innerHTML = '<span class="crm-todo-yonetici-etiket">ATAMA</span> Yöneticiden görev' +
				(olusturanAd ? (' · ' + olusturanAd) : '');
			li.insertBefore(yBanner, check);
		}
		var kurumAd = String(info.kurum || '').trim();
		if (kurumAd || !manuelMi) {
			var kurumEl = document.createElement('span');
			kurumEl.className = 'crm-todo-kurum';
			kurumEl.textContent = kurumAd ? kurumAd : 'Kurum belirtilmedi';
			body.appendChild(kurumEl);
		}
		body.appendChild(title);
		if (isAdminGorevGorunumu() && (atananAd || atananId)) {
			var atanan = document.createElement('span');
			atanan.className = 'crm-todo-atanan';
			atanan.textContent = atananAd || ('Kullanıcı #' + atananId);
			body.appendChild(atanan);
		}
		body.appendChild(meta);
		li.appendChild(body);
		if (isAdminGorevGorunumu() && !done) {
			var ataWrap = document.createElement('div');
			var ataBtn = document.createElement('button');
			var ataMenu = document.createElement('div');
			ataWrap.className = 'crm-todo-ata-wrap';
			ataBtn.type = 'button';
			ataBtn.className = 'crm-todo-ata-btn';
			ataBtn.textContent = 'Görev Ata';
			ataMenu.className = 'crm-todo-ata-menu';
			ataMenu.hidden = true;
			ataMenu.innerHTML =
				'<label>Personel seçin</label>' +
				'<select class="crm-todo-ata-select"><option value="">Listeleniyor...</option></select>' +
				'<button type="button" class="crm-todo-ata-onay">Onayla</button>';
			ataWrap.appendChild(ataBtn);
			ataWrap.appendChild(ataMenu);
			li.appendChild(ataWrap);
		}
		if (etiketMetni) {
			var badge = document.createElement('span');
			badge.className = 'crm-todo-badge' + (manuelMi ? ' is-manuel' : ' is-gorusme');
			badge.textContent = etiketMetni;
			li.appendChild(badge);
		}

		if (!done) {
			var del = document.createElement('button');
			del.type = 'button';
			del.className = 'crm-todo-del';
			del.setAttribute('aria-label', 'Görevi sil');
			del.innerHTML = '&times;';
			li.appendChild(del);
		}

		return li;
	}

	function navRozetleriGuncelle() {
		var notBadge = document.getElementById('nav-badge-notlar');
		var gorevBadge = document.getElementById('nav-badge-gorev');
		var notSayisi = typeof window.crmSonNotSayisi === 'number' ? window.crmSonNotSayisi : 0;
		var aktifGorev = 0;
		var yoneticiGorev = 0;
		var i;
		for (i = 0; i < todos.length; i++) {
			if (!todos[i].done) {
				aktifGorev++;
				if (banaYoneticiAtamasiMi(todos[i]))
					yoneticiGorev++;
			}
		}
		if (notBadge) {
			notBadge.textContent = String(notSayisi);
			notBadge.hidden = notSayisi <= 0;
			notBadge.classList.toggle('is-accent', notSayisi > 0);
		}
		if (gorevBadge) {
			gorevBadge.textContent = String(aktifGorev);
			gorevBadge.hidden = aktifGorev <= 0;
			gorevBadge.classList.toggle('is-warn', yoneticiGorev > 0);
		}
		var statGorev = document.getElementById('stat-gorev');
		if (statGorev)
			statGorev.textContent = aktifGorev > 0 ? (aktifGorev + ' Görev') : '0 Görev';
	}
	window.crmNavRozetleriGuncelle = navRozetleriGuncelle;

	function gorevItemdenLi(item) {
		return createGorevLi(item.title, {
			id: item.id,
			due: item.due,
			source: item.source,
			label: item.label || (item.source === 'ai' ? 'Görüşme' : 'Manuel'),
			done: !!item.done,
			doneAt: item.doneAt,
			dbId: item.dbId,
			kurum: item.kurum || '',
			assigned_user_id: item.assigned_user_id,
			assigned_user_name: item.assigned_user_name,
			user_id: item.user_id,
			olusturan_adi: item.olusturan_adi,
			gorusme_sahibi_adi: item.gorusme_sahibi_adi,
			company_id: item.company_id
		});
	}

	function renderTodos() {
		var i, item, li, aktif = 0, biten = 0, gosterilen = 0;
		var Q = window.CrmQuery;
		var liste;

		purgeExpiredTodos();

		liste = todos.slice();
		if (Q && gorevSorgu.q) {
			liste = liste.filter(function (t) {
				return Q.match(gorevSorgu.q, [t.title, t.kurum, t.assigned_user_name, t.olusturan_adi, t.label]);
			});
		}
		/* Aktif görünümünde tamamlananlar Tamamlananlar kutusuna gider;
		   dropdown onları silmez. Yalnızca "Tamamlanan" seçilince açık liste gizlenir. */

		liste.sort(function (a, b) {
			var aY = banaYoneticiAtamasiMi(a) ? 0 : 1;
			var bY = banaYoneticiAtamasiMi(b) ? 0 : 1;
			if (aY !== bY) return aY - bY;
			var key = gorevSorgu.sort || 'due-asc';
			if (key === 'title-asc' || key === 'title-desc')
				return Q ? Q.cmp(a.title, b.title, key === 'title-desc' ? 'desc' : 'asc') : 0;
			if (key === 'durum-asc')
				return (!!a.done === !!b.done) ? 0 : (a.done ? 1 : -1);
			if (key === 'durum-desc')
				return (!!a.done === !!b.done) ? 0 : (a.done ? -1 : 1);
			if (key === 'due-desc')
				return Q ? Q.cmp(a.due || '', b.due || '', 'desc') : 0;
			return Q ? Q.cmp(a.due || '', b.due || '', 'asc') : 0;
		});

		if (todoList)
			todoList.innerHTML = '';
		if (todoDoneList)
			todoDoneList.innerHTML = '';

		for (i = 0; i < liste.length; i++) {
			item = liste[i];
			if (gorevSorgu.durum === 'tamamlanan' && !item.done)
				continue;
			li = gorevItemdenLi(item);
			gosterilen++;
			if (item.done) {
				if (todoDoneList)
					todoDoneList.appendChild(li);
				biten++;
			} else if (todoList) {
				todoList.appendChild(li);
				aktif++;
			}
		}

		var emptyEl = todoEmptyEl();
		if (emptyEl) {
			if (gorevSorgu.durum === 'tamamlanan') {
				emptyEl.style.display = biten ? 'none' : '';
				emptyEl.textContent = todos.length ? 'Tamamlanan görev yok.' : 'Henüz görev yok';
			} else if (aktif === 0 && biten === 0) {
				emptyEl.style.display = '';
				emptyEl.textContent = todos.length
					? 'Arama veya filtreyle eşleşen görev yok.'
					: 'Henüz görev yok';
			} else {
				emptyEl.style.display = 'none';
			}
		}
		if (todoDoneWrap)
			todoDoneWrap.hidden = biten === 0;
		if (todoList)
			todoList.hidden = gorevSorgu.durum === 'tamamlanan';
		var sonucEl = document.getElementById('gorev-sonuc');
		if (sonucEl)
			sonucEl.textContent = todos.length
				? (gosterilen + ' / ' + todos.length + ' görev')
				: '';
		if (typeof window.crmNavRozetleriGuncelle === 'function')
			window.crmNavRozetleriGuncelle();
	}

	window.crmTodosYenile = function () {
		if (typeof sunucudanGorevleriYukle === 'function') {
			return sunucudanGorevleriYukle().catch(function () {
				renderTodos();
			});
		}
		renderTodos();
		return Promise.resolve();
	};

	function addTodo(entry) {
		var title = (entry.title || '').trim();
		var due = entry.due ? String(entry.due) : '';
		var i;
		var norm;

		if (!title)
			return false;

		norm = title.toLocaleLowerCase('tr-TR');
		function todoIndeksBul() {
			var j;
			if (entry.dbId) {
				for (j = 0; j < todos.length; j++) {
					if (String(todos[j].dbId || '') === String(entry.dbId))
						return j;
				}
			}
			for (j = 0; j < todos.length; j++) {
				if (String(todos[j].title || '').trim().toLocaleLowerCase('tr-TR') === norm)
					return j;
			}
			return -1;
		}
		i = todoIndeksBul();
		if (i >= 0) {
			var degisti = false;
			['assigned_user_id', 'assigned_user_name', 'user_id', 'company_id', 'dbId', 'due', 'source', 'label', 'gorusme_sahibi_adi', 'kurum'].forEach(function (k) {
				if (entry[k] != null && entry[k] !== '' && todos[i][k] !== entry[k]) {
					todos[i][k] = entry[k];
					degisti = true;
				}
			});
			if (entry.dbId && entry.done != null && !!todos[i].done !== !!entry.done) {
				todos[i].done = !!entry.done;
				degisti = true;
			}
			if (degisti) {
				saveTodos();
				renderTodos();
			}
			return true;
		}

		todos.unshift({
			id: Date.now() + '-' + Math.random().toString(16).slice(2),
			title: title,
			due: due,
			source: entry.source || 'manual',
			label: entry.label || (entry.source === 'ai' ? 'AI Tespit Etti' : 'Manuel'),
			kurum: entry.kurum || '',
			assigned_user_id: entry.assigned_user_id || null,
			assigned_user_name: entry.assigned_user_name || '',
			gorusme_sahibi_adi: entry.gorusme_sahibi_adi || '',
			user_id: entry.user_id || null,
			company_id: entry.company_id || null,
			dbId: entry.dbId || null,
			done: !!entry.done,
			createdAt: new Date().toISOString()
		});
		saveTodos();
		renderTodos();
		return true;
	}

	function toggleTodo(id) {
		var i, item = null, onceki;
		for (i = 0; i < todos.length; i++) {
			if (String(todos[i].id) === String(id)) {
				item = todos[i];
				break;
			}
		}
		if (!item)
			return;
		onceki = !!item.done;
		item.done = !item.done;
		item.doneAt = item.done ? new Date().toISOString() : null;
		saveTodos();
		renderTodos();
		if (item.dbId) {
			fetchJson(CRM_API + '/api/gorevler/' + item.dbId, {
				method: 'PUT',
				headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
				body: JSON.stringify({ tamamlandi: item.done })
			}).then(function () {
				if (typeof window.yoneticiNotlariniYukle === 'function')
					window.yoneticiNotlariniYukle();
				if (typeof window.loadGlobalStats === 'function')
					window.loadGlobalStats();
			}).catch(function (err) {
				item.done = onceki;
				item.doneAt = onceki ? item.doneAt : null;
				saveTodos();
				renderTodos();
				gosterToast((err && err.message) || 'Görev güncellenemedi.', 'hata');
			});
		} else if (typeof window.yoneticiNotlariniYukle === 'function') {
			window.yoneticiNotlariniYukle();
		}
	}

	function removeTodo(id) {
		todos = todos.filter(function (item) { return String(item.id) !== String(id); });
		saveTodos();
		renderTodos();
	}

	function todayISO() {
		var d = new Date();
		var m = d.getMonth() + 1;
		var day = d.getDate();
		return d.getFullYear() + '-' + (m < 10 ? '0' : '') + m + '-' + (day < 10 ? '0' : '') + day;
	}

	function extractGorevler(data) {
		var payload;
		if (!data || typeof data !== 'object')
			return [];
		if (Array.isArray(data.gorevler))
			return data.gorevler;
		payload = unwrapPayload(data);
		if (payload && Array.isArray(payload.gorevler))
			return payload.gorevler;
		return [];
	}

	function gorevMetni(item) {
		if (typeof item !== 'string')
			return '';
		var metin = item.replace(/\s+/g, ' ').trim();
		if (!metin || metin.split(' ').length > 20)
			return '';
		return metin;
	}

	function bindGorevlerToUI(data) {
		var gorevler = (data && Array.isArray(data.gorevler)) ? data.gorevler : [];
		var i, text, eklendi = 0;

		for (i = 0; i < gorevler.length; i++) {
			text = gorevMetni(gorevler[i]);
			if (!text)
				continue;
			if (addTodo({
				title: text,
				due: todayISO(),
				source: 'ai',
				label: 'AI Tespit Etti'
			}))
				eklendi++;
		}
		return eklendi;
	}

	window.ekleAiGorev = function (metin, extra) {
		extra = extra || {};
		return addTodo({
			title: metin,
			due: extra.due || todayISO(),
			source: extra.source || 'ai',
			label: extra.label || (extra.source === 'manual' || extra.source === 'manuel' ? 'Manuel' : 'Görüşme'),
			kurum: extra.kurum || '',
			assigned_user_id: extra.assigned_user_id,
			assigned_user_name: extra.assigned_user_name,
			user_id: extra.user_id,
			company_id: extra.company_id,
			dbId: extra.dbId,
			done: !!extra.done
		});
	};

	window.bugunISO = todayISO;

	var sirketKullaniciOnbellegi = {};

	function ataMenuleriniKapat(haric) {
		var menuler = document.querySelectorAll('.crm-todo-ata-menu');
		var i;
		for (i = 0; i < menuler.length; i++) {
			if (menuler[i] !== haric)
				menuler[i].hidden = true;
		}
	}

	function ataMenusunuAc(li) {
		var menu = li.querySelector('.crm-todo-ata-menu');
		var select = li.querySelector('.crm-todo-ata-select');
		var companyId = li.dataset.companyId;
		var dbId = li.dataset.dbId;
		var atananId = li.dataset.assignedUserId || '';
		var cacheKey;
		if (!dbId) {
			gosterToast('Bu görev henüz sunucuya kayıtlı değil.', 'hata');
			return;
		}
		if (!companyId) {
			gosterToast('Bu görevin şirket bilgisi yok. Yalnızca aynı şirket personeline atama yapılabilir.', 'hata');
			return;
		}
		if (!menu || !select)
			return;
		if (!menu.hidden) {
			menu.hidden = true;
			return;
		}
		ataMenuleriniKapat(menu);
		menu.hidden = false;
		select.innerHTML = '<option value="">Yükleniyor...</option>';
		function doldur(liste) {
			var k, u, ad, opt, benimId = oturumKullaniciId();
			select.innerHTML = '';
			opt = document.createElement('option');
			opt.value = '';
			opt.textContent = liste.length ? 'Personel seçin' : 'Personel bulunamadı';
			select.appendChild(opt);
			for (k = 0; k < liste.length; k++) {
				u = liste[k];
				ad = (u.ad_soyad || u.kullanici_adi || ('#' + u.id));
				if (parseInt(u.id, 10) === benimId)
					ad = ad + ' (ben)';
				opt = document.createElement('option');
				opt.value = String(u.id);
				opt.textContent = ad;
				select.appendChild(opt);
			}
			if (atananId)
				select.value = String(atananId);
			if (!liste.length)
				gosterToast('Bu şirkette listelenecek personel yok.', 'hata');
		}
		cacheKey = String(companyId);
		if (sirketKullaniciOnbellegi[cacheKey]) {
			doldur(sirketKullaniciOnbellegi[cacheKey]);
			return;
		}
		fetchJson(CRM_API + '/api/companies/' + companyId + '/users', {
			headers: { Accept: 'application/json' }
		}).then(function (data) {
			var liste = (data && data.kullanicilar) || [];
			sirketKullaniciOnbellegi[cacheKey] = liste;
			doldur(liste);
		}).catch(function (err) {
			select.innerHTML = '<option value="">Liste alınamadı</option>';
			gosterToast((err && err.message) || 'Personel listesi alınamadı.', 'hata');
		});
	}

	function goreviAtaOnayla(li) {
		var select = li.querySelector('.crm-todo-ata-select');
		var dbId = li.dataset.dbId;
		var userId = select ? parseInt(select.value, 10) : 0;
		var secilenAd = '';
		if (!dbId) {
			gosterToast('Bu görev henüz sunucuya kayıtlı değil.', 'hata');
			return;
		}
		if (!userId) {
			gosterToast('Lütfen bir personel seçin.', 'hata');
			return;
		}
		if (select && select.selectedIndex >= 0)
			secilenAd = select.options[select.selectedIndex].textContent;
		fetchJson(CRM_API + '/api/gorevler/' + dbId + '/ata', {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
			body: JSON.stringify({ assigned_user_id: userId })
		}).then(function (data) {
			var gorev = data && data.gorev;
			var i, ad, uid, benimListe;
			ad = (gorev && gorev.assigned_user_name) || secilenAd;
			uid = mevcutKullaniciIdAl();
			benimListe = !isAdminGorevGorunumu() || gorevKapsamAl() === 'benim';
			if (benimListe && uid && userId !== uid) {
				todos = todos.filter(function (t) {
					return String(t.id) !== String(li.dataset.id) && String(t.dbId) !== String(dbId);
				});
				saveTodos();
				renderTodos();
			} else {
				for (i = 0; i < todos.length; i++) {
					if (String(todos[i].id) === String(li.dataset.id) || String(todos[i].dbId) === String(dbId)) {
						todos[i].assigned_user_id = userId;
						todos[i].assigned_user_name = ad;
						if (gorev && gorev.company_id)
							todos[i].company_id = gorev.company_id;
						break;
					}
				}
				saveTodos();
				renderTodos();
			}
			var atananEl = li.querySelector('[data-atanan-etiket]');
			if (atananEl)
				atananEl.textContent = ad;
			li.dataset.assignedUserId = String(userId);
			if (gorev && gorev.company_id)
				li.dataset.companyId = String(gorev.company_id);
			var ataMenu = li.querySelector('.crm-todo-ata-menu');
			if (ataMenu)
				ataMenu.hidden = true;
			gosterToast('Görev ' + ad + ' kişisine atandı.', 'ok');
			if (typeof window.yoneticiNotlariniYukle === 'function')
				window.yoneticiNotlariniYukle();
			if (typeof sunucudanGorevleriYukle === 'function' && benimListe)
				sunucudanGorevleriYukle();
		}).catch(function (err) {
			gosterToast((err && err.message) || 'Atama reddedildi.', 'hata');
		});
	}

	window.crmAtaMenusunuAc = ataMenusunuAc;
	window.crmGoreviAtaOnayla = goreviAtaOnayla;

	document.addEventListener('click', function (event) {
		if (event.target.closest && event.target.closest('.crm-todo-ata-wrap'))
			return;
		ataMenuleriniKapat();
	});

	function oturumKullaniciId() {
		var u = window.Auth && window.Auth.getUser ? window.Auth.getUser() : null;
		return u && u.id ? parseInt(u.id, 10) : 0;
	}

	function yoneticiNotlariniYukle() {
		/* "Yöneticiden Gelen Notlar" paneli kaldırıldı; atanan görevler Görevler listesinde görünür. */
	}

	window.yoneticiNotlariniYukle = yoneticiNotlariniYukle;

	function onTodoListClick(event) {
		var check = event.target.closest ? event.target.closest('.crm-todo-check') : null;
		var del = event.target.closest ? event.target.closest('.crm-todo-del') : null;
		var ataBtn = event.target.closest ? event.target.closest('.crm-todo-ata-btn') : null;
		var ataOnay = event.target.closest ? event.target.closest('.crm-todo-ata-onay') : null;
		var li = event.target.closest ? event.target.closest('.crm-todo-item') : null;
		if (event.target.closest && event.target.closest('.crm-todo-ata-menu') && !ataOnay)
			return;
		if (!li || !li.dataset.id)
			return;
		if (ataBtn) {
			event.preventDefault();
			event.stopPropagation();
			ataMenusunuAc(li);
			return;
		}
		if (ataOnay) {
			event.preventDefault();
			event.stopPropagation();
			goreviAtaOnayla(li);
			return;
		}
		if (check) {
			event.preventDefault();
			toggleTodo(li.dataset.id);
			return;
		}
		if (del) {
			event.preventDefault();
			removeTodo(li.dataset.id);
		}
	}

	if (todoList)
		todoList.addEventListener('click', onTodoListClick);
	if (todoDoneList)
		todoDoneList.addEventListener('click', onTodoListClick);

	loadTodos();

	function apiGorevindenTodo(gorev) {
		if (!gorev || typeof gorev !== 'object')
			return null;
		var title = String(gorev.baslik || gorev.title || gorev.description || '').trim();
		if (!title)
			return null;
		var due = gorev.due_date || gorev.tarih || '';
		return {
			title: title,
			due: due ? String(due).slice(0, 10) : '',
			source: (gorev.kaynak === 'manuel' || gorev.kaynak === 'manual') ? 'manual' : 'ai',
			label: (gorev.kaynak === 'manuel' || gorev.kaynak === 'manual') ? 'Manuel' : 'AI Tespit Etti',
			kurum: gorev.kurum_adi || '',
			dbId: gorev.id,
			assigned_user_id: gorev.assigned_user_id,
			assigned_user_name: gorev.assigned_user_name || gorev.gorusme_sahibi_adi,
			gorusme_sahibi_adi: gorev.gorusme_sahibi_adi || '',
			user_id: gorev.user_id,
			olusturan_adi: gorev.olusturan_adi || '',
			company_id: gorev.company_id,
			done: !!gorev.tamamlandi
		};
	}

	function sunucudanGorevleriYukle() {
		var kapsam = gorevKapsamAl();
		var url = CRM_API + '/api/gorevler';
		if (isAdminGorevGorunumu() && kapsam)
			url += '?kapsam=' + encodeURIComponent(kapsam);
		todoKapsamPaneliHazirla();
		return fetchJson(url, {
			headers: { Accept: 'application/json' }
		}).then(function (data) {
			var liste = (data && Array.isArray(data.gorevler)) ? data.gorevler : [];
			var i, kayit;
			if (kapsam === 'ekip_gorusmeleri')
				todos = [];
			else
				todos = todos.filter(function (t) { return !t.dbId; });
			for (i = 0; i < liste.length; i++) {
				kayit = apiGorevindenTodo(liste[i]);
				if (kayit)
					addTodo(kayit);
			}
			saveTodos();
			renderTodos();
			if (typeof window.loadGlobalStats === 'function')
				window.loadGlobalStats();
			return liste;
		});
	}

	window.crmGorevleriYenile = sunucudanGorevleriYukle;

	function bagimsizGorevKaydet(baslik, due, btn, assignedUserId, urunId) {
		baslik = String(baslik || '').trim();
		due = due ? String(due).trim() : '';
		if (!baslik) {
			if (typeof gosterToast === 'function')
				gosterToast('Görev metnini yazın.', 'hata');
			return Promise.reject(new Error('Görev metnini yazın.'));
		}
		if (btn) btn.disabled = true;
		var govde = {
			description: baslik,
			baslik: baslik,
			due_date: due || null,
			gorusme_id: null,
			analysis_id: null,
			meeting_id: null
		};
		if (assignedUserId != null && String(assignedUserId).trim() !== '') {
			var atananSayi = parseInt(assignedUserId, 10);
			if (!isNaN(atananSayi))
				govde.assigned_user_id = atananSayi;
		}
		if (urunId != null && String(urunId).trim() !== '') {
			var urunSayi = parseInt(urunId, 10);
			if (!isNaN(urunSayi))
				govde.urun_id = urunSayi;
		}
		return fetchJson(CRM_API + '/api/gorevler', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
			body: JSON.stringify(govde)
		}).then(function (data) {
			var kayit = apiGorevindenTodo(data && data.gorev);
			if (!kayit) {
				kayit = {
					title: baslik,
					due: due || '',
					source: 'manual',
					label: 'Manuel',
					dbId: data && data.gorev && data.gorev.id,
					assigned_user_id: data && data.gorev && data.gorev.assigned_user_id,
					assigned_user_name: data && data.gorev && data.gorev.assigned_user_name,
					user_id: data && data.gorev && data.gorev.user_id,
					company_id: data && data.gorev && data.gorev.company_id,
					done: false
				};
			}
			addTodo(kayit);
			renderTodos();
			if (typeof gosterToast === 'function')
				gosterToast('Görev eklendi.', 'ok');
			return sunucudanGorevleriYukle().then(function () {
				return data;
			}).catch(function () {
				return data;
			});
		}).catch(function (err) {
			if (typeof gosterToast === 'function')
				gosterToast((err && err.message) || 'Görev eklenemedi.', 'hata');
			throw err;
		}).then(function (data) {
			if (btn) btn.disabled = false;
			return data;
		}, function (err) {
			if (btn) btn.disabled = false;
			throw err;
		});
	}

	window.crmBagimsizGorevKaydet = bagimsizGorevKaydet;

	function urunSelectSifirla(selectEl) {
		if (!selectEl)
			return;
		selectEl.innerHTML = '<option value="">Ürün seçin</option>';
	}

	function calisanSelectSifirla(selectEl, metin) {
		if (!selectEl)
			return;
		selectEl.innerHTML = '<option value="">' + (metin || 'Önce ürün seçin') + '</option>';
		selectEl.disabled = true;
		selectEl.value = '';
	}

	function urunListesiniDoldur(selectEl, urunler) {
		var i, u, opt;
		urunSelectSifirla(selectEl);
		if (!selectEl)
			return;
		for (i = 0; i < urunler.length; i++) {
			u = urunler[i];
			if (!u || !u.id)
				continue;
			opt = document.createElement('option');
			opt.value = String(u.id);
			opt.textContent = (u.name || u.code || ('Ürün #' + u.id))
				+ (u.company_name ? (' — ' + u.company_name) : '');
			selectEl.appendChild(opt);
		}
	}

	function calisanListesiniDoldur(selectEl, liste) {
		var i, u, opt, ad;
		if (!selectEl)
			return;
		selectEl.innerHTML = '';
		opt = document.createElement('option');
		opt.value = '';
		opt.textContent = liste.length ? 'Çalışan seçin' : 'Bu üründe çalışan yok';
		selectEl.appendChild(opt);
		for (i = 0; i < liste.length; i++) {
			u = liste[i];
			if (!u || !u.id)
				continue;
			ad = (u.ad_soyad || u.kullanici_adi || ('#' + u.id));
			opt = document.createElement('option');
			opt.value = String(u.id);
			opt.textContent = ad + (u.company_name ? (' · ' + u.company_name) : '');
			selectEl.appendChild(opt);
		}
		selectEl.disabled = !liste.length;
	}

	function urunCalisanlariniYukle(urunId, calisanSelect) {
		calisanSelectSifirla(calisanSelect, 'Yükleniyor...');
		if (!urunId) {
			calisanSelectSifirla(calisanSelect, 'Önce ürün seçin');
			return Promise.resolve([]);
		}
		return fetchJson(CRM_API + '/api/urunler/' + urunId + '/kullanicilar', {
			headers: { Accept: 'application/json' }
		}).then(function (data) {
			var liste = (data && data.kullanicilar) || [];
			calisanListesiniDoldur(calisanSelect, liste);
			return liste;
		}).catch(function (err) {
			calisanSelectSifirla(calisanSelect, 'Liste alınamadı');
			if (typeof gosterToast === 'function')
				gosterToast((err && err.message) || 'Çalışan listesi alınamadı.', 'hata');
			return [];
		});
	}

	function personelAtamaFormuBagla(opts) {
		var form = document.getElementById(opts.formId);
		var urunEl = document.getElementById(opts.urunId);
		var calisanEl = document.getElementById(opts.calisanId);
		var baslikEl = document.getElementById(opts.baslikId);
		if (!form || !urunEl || !calisanEl)
			return;
		urunEl.addEventListener('change', function () {
			urunCalisanlariniYukle(urunEl.value, calisanEl);
		});
		if (opts.skipSubmit || !baslikEl)
			return;
		form.addEventListener('submit', function (event) {
			event.preventDefault();
			var baslik = String(baslikEl.value || '').trim();
			var urunId = String(urunEl.value || '').trim();
			var calisanId = String(calisanEl.value || '').trim();
			var btn = form.querySelector('button[type="submit"]');
			if (!urunId) {
				if (typeof gosterToast === 'function')
					gosterToast('Önce ürün seçin.', 'hata');
				urunEl.focus();
				return;
			}
			if (!calisanId) {
				if (typeof gosterToast === 'function')
					gosterToast('Çalışan seçin.', 'hata');
				calisanEl.focus();
				return;
			}
			if (!baslik) {
				if (typeof gosterToast === 'function')
					gosterToast('Görev metnini yazın.', 'hata');
				baslikEl.focus();
				return;
			}
			bagimsizGorevKaydet(baslik, '', btn, calisanId, urunId).then(function () {
				baslikEl.value = '';
				urunEl.value = '';
				calisanSelectSifirla(calisanEl, 'Önce ürün seçin');
				baslikEl.focus();
			}).catch(function () {});
		});
	}

	function adminAtamaPanelleriniHazirla() {
		var isAdmin = !!(window.Auth && window.Auth.isAdmin && window.Auth.isAdmin());
		var dashUrun = document.getElementById('dash-personel-urun');
		var todoUrun = document.getElementById('todo-ata-urun');
		var fabUrun = document.getElementById('fab-gorev-urun');
		var urunSelectler = [dashUrun, todoUrun, fabUrun].filter(Boolean);
		todoKapsamPaneliHazirla();
		if (!isAdmin)
			return Promise.resolve([]);
		function yukleGoster(el) {
			if (!el) return;
			el.innerHTML = '<option value="">Ürünler yükleniyor...</option>';
			el.disabled = true;
		}
		urunSelectler.forEach(yukleGoster);
		return fetchJson(CRM_API + '/api/urunler', {
			headers: { Accept: 'application/json' }
		}).then(function (data) {
			var urunler = (data && data.urunler) || [];
			urunSelectler.forEach(function (el) {
				urunListesiniDoldur(el, urunler);
				el.disabled = false;
			});
			if (!urunler.length && typeof gosterToast === 'function')
				gosterToast('Veritabanında aktif ürün bulunamadı.', 'hata');
			return urunler;
		}).catch(function (err) {
			urunSelectler.forEach(function (el) {
				el.innerHTML = '<option value="">Ürünler alınamadı</option>';
				el.disabled = false;
			});
			if (typeof gosterToast === 'function')
				gosterToast((err && err.message) || 'Ürün listesi alınamadı.', 'hata');
			return [];
		});
	}

	window.crmAdminAtamaPanelleriniHazirla = adminAtamaPanelleriniHazirla;

	if (todoForm) {
		todoForm.addEventListener('submit', function (event) {
			event.preventDefault();
			if (!todoBaslik)
				return;
			var baslik = String(todoBaslik.value || '').trim();
			var due = todoTarih ? String(todoTarih.value || '').trim() : '';
			var btn = todoForm.querySelector('.crm-todo-add');
			if (!baslik) {
				if (typeof gosterToast === 'function')
					gosterToast('Görev metnini yazın.', 'hata');
				todoBaslik.focus();
				return;
			}
			bagimsizGorevKaydet(baslik, due, btn).then(function () {
				todoBaslik.value = '';
				if (todoTarih) todoTarih.value = '';
				todoBaslik.focus();
			}).catch(function () {});
		});
	}

	function kendimeHizliGorevBagla(formId, baslikId, btnId) {
		var form = document.getElementById(formId);
		var baslikEl = document.getElementById(baslikId);
		if (!form)
			return;
		form.addEventListener('submit', function (event) {
			event.preventDefault();
			var baslik = String((baslikEl && baslikEl.value) || '').trim();
			var btn = document.getElementById(btnId);
			if (!baslik) {
				if (typeof gosterToast === 'function')
					gosterToast('Görev metnini yazın.', 'hata');
				if (baslikEl) baslikEl.focus();
				return;
			}
			bagimsizGorevKaydet(baslik, '', btn).then(function () {
				if (baslikEl) {
					baslikEl.value = '';
					baslikEl.focus();
				}
			}).catch(function () {});
		});
	}
	kendimeHizliGorevBagla('dash-hizli-gorev-form', 'dash-hizli-gorev-baslik', 'dash-hizli-gorev-ekle');

	personelAtamaFormuBagla({
		formId: 'dash-personel-gorev-form',
		urunId: 'dash-personel-urun',
		calisanId: 'dash-personel-calisan',
		baslikId: 'dash-personel-baslik'
	});
	personelAtamaFormuBagla({
		formId: 'todo-ata-form',
		urunId: 'todo-ata-urun',
		calisanId: 'todo-ata-calisan',
		baslikId: 'todo-ata-baslik'
	});
	personelAtamaFormuBagla({
		formId: 'fab-gorev-form',
		urunId: 'fab-gorev-urun',
		calisanId: 'fab-gorev-calisan',
		baslikId: 'fab-gorev-baslik',
		skipSubmit: true
	});

	adminAtamaPanelleriniHazirla();
	if (window.Auth && typeof window.Auth.refreshUser === 'function') {
		window.Auth.refreshUser().then(adminAtamaPanelleriniHazirla).catch(function () {});
	}

	(function gorevAramaBagla() {
		var arama = document.getElementById('gorev-arama');
		var durum = document.getElementById('gorev-filtre-durum');
		var sirala = document.getElementById('gorev-siralama');
		var t;
		if (arama) {
			arama.addEventListener('input', function () {
				clearTimeout(t);
				t = setTimeout(function () {
					gorevSorgu.q = arama.value || '';
					renderTodos();
				}, 80);
			});
		}
		if (durum) {
			durum.addEventListener('change', function () {
				gorevSorgu.durum = durum.value || 'aktif';
				renderTodos();
			});
		}
		if (sirala) {
			sirala.addEventListener('change', function () {
				gorevSorgu.sort = sirala.value || 'due-asc';
				renderTodos();
			});
		}
	})();

	(function todoKapsamSeciciBagla() {
		var wrap = document.getElementById('todo-kapsam');
		if (!wrap)
			return;
		wrap.addEventListener('click', function (event) {
			var btn = event.target.closest('[data-kapsam]');
			if (!btn || !wrap.contains(btn))
				return;
			var kapsam = btn.getAttribute('data-kapsam');
			if (!kapsam || kapsam === gorevKapsamAl())
				return;
			gorevKapsamYaz(kapsam);
			todoKapsamPaneliHazirla();
			sunucudanGorevleriYukle().catch(function () {});
		});
	})();

	(function gorevComposerSeciciBagla() {
		document.addEventListener('click', function (event) {
			var btn = event.target.closest ? event.target.closest('[data-composer]') : null;
			if (!btn)
				return;
			var wrap = btn.closest('#todo-composer-tabs, #dash-composer-tabs');
			if (!wrap)
				return;
			var mod = btn.getAttribute('data-composer');
			if (!mod || (mod !== 'kendime' && mod !== 'personele'))
				return;
			if (mod === gorevComposerAl())
				return;
			gorevComposerYaz(mod);
			gorevComposerPanelleriniGuncelle();
		});
	})();

	function gorevEklemeAlaniaKaydir(composerId) {
		var el = document.getElementById(composerId);
		if (!el || el.hidden)
			return;
		if (typeof el.scrollIntoView === 'function')
			el.scrollIntoView({ behavior: 'smooth', block: 'start' });
		var admin = isAdminGorevGorunumu();
		var mod = gorevComposerAl();
		var focusId;
		if (composerId === 'todo-composer')
			focusId = (admin && mod === 'personele') ? 'todo-ata-baslik' : 'todo-baslik';
		else
			return;
		window.setTimeout(function () {
			var inp = document.getElementById(focusId);
			if (inp && !inp.disabled)
				inp.focus();
		}, 350);
	}

	var btnGorevlerEkle = document.getElementById('btn-gorevler-ekle');
	if (btnGorevlerEkle)
		btnGorevlerEkle.addEventListener('click', function () {
			gorevEklemeAlaniaKaydir('todo-composer');
		});

	function setRecordingUI(recording) {
		isRecording = recording;
		btnSes.classList.toggle('is-recording', recording);
		btnSes.classList.toggle('fa-microphone', !recording);
		btnSes.classList.toggle('fa-stop', recording);
		btnSes.textContent = recording ? 'Durdur ve analiz et' : 'Konuşmaya başla';
		btnSes.setAttribute('aria-pressed', recording ? 'true' : 'false');
		var panel = document.getElementById('crm-not-ekle-panel');
		if (panel)
			panel.classList.toggle('is-recording', recording);
	}

	function normalizeBase(text) {
		if (!text)
			return '';
		if (/\s$/.test(text))
			return text;
		return text + ' ';
	}

	function appendSpeechChunk(prev, next) {
		prev = String(prev || '');
		next = String(next || '');
		if (!next)
			return prev;
		if (!prev)
			return next;
		var p = prev.replace(/\s+$/g, '');
		var n = next.replace(/^\s+/g, '');
		if (!n)
			return prev;
		if (n.indexOf(p) === 0)
			return next;
		if (p.length >= n.length && p.slice(-n.length) === n)
			return prev;
		var max = Math.min(p.length, n.length);
		var len;
		for (len = max; len >= 4; len--) {
			if (p.slice(-len) === n.slice(0, len))
				return p + n.slice(len);
		}
		return p + (/^\s/.test(next) || /\s$/.test(prev) ? '' : ' ') + n;
	}

	function yazKonusmaMetni(interim) {
		if (!textarea)
			return;
		textarea.value = appendSpeechChunk(baseText, appendSpeechChunk(frozenSpeech, interim || ''));
		textarea.scrollTop = textarea.scrollHeight;
	}

	function konusmayiDondur() {
		if (!textarea)
			return;
		baseText = normalizeBase(textarea.value);
		frozenSpeech = '';
	}

	function stopRecording() {
		isRecording = false;
		speechRestarting = false;
		setRecordingUI(false);

		if (recognition) {
			try {
				recognition.stop();
			} catch (err) {
				/* ignore */
			}
		}

		setStatus('');

		window.setTimeout(function () {
			var metin = textarea ? String(textarea.value || '').trim() : '';
			if (metin && typeof window.calistirAnaliz === 'function' && !window.analizDevamEdiyor)
				window.calistirAnaliz();
		}, 700);
	}

	function startRecording() {
		if (!recognition) {
			showError('Bu tarayıcı ses tanımayı desteklemiyor. Chrome veya Edge kullanın; notu elle yazabilirsiniz.');
			return;
		}

		hideError();
		if (textarea)
			textarea.value = '';
		baseText = '';
		frozenSpeech = '';

		try {
			recognition.start();
		} catch (err) {
			showError('Mikrofon başlatılamadı. Sekmenin mikrofon iznini kontrol edin.');
		}
	}

	if (SpeechRecognition) {
		recognition = new SpeechRecognition();
		recognition.lang = 'tr-TR';
		recognition.continuous = true;
		recognition.interimResults = true;
		recognition.maxAlternatives = 1;

		recognition.onstart = function () {
			speechRestarting = false;
			setRecordingUI(true);
			setStatus('Dinleniyor… konuşun. Bitince Durdur ve analiz et’e basın.', true);
		};

		recognition.onresult = function (event) {
			var interimTranscript = '';
			var i;
			var parca;

			for (i = event.resultIndex; i < event.results.length; i++) {
				parca = event.results[i][0] ? event.results[i][0].transcript : '';
				if (!parca)
					continue;
				if (event.results[i].isFinal)
					frozenSpeech = appendSpeechChunk(frozenSpeech, parca);
				else
					interimTranscript += parca;
			}

			yazKonusmaMetni(interimTranscript);
		};

		recognition.onerror = function (event) {
			if (event.error === 'no-speech' || event.error === 'aborted')
				return;

			if (event.error === 'not-allowed' || event.error === 'service-not-allowed') {
				stopRecording();
				showError('Mikrofon izni reddedildi.');
				return;
			}

			if (event.error === 'audio-capture') {
				stopRecording();
				showError('Mikrofona erişilemedi.');
				return;
			}

			showError('Ses tanıma hatası: ' + event.error);
		};

		recognition.onend = function () {
			if (!isRecording) {
				setRecordingUI(false);
				setStatus('');
				return;
			}

			konusmayiDondur();
			if (speechRestarting)
				return;
			speechRestarting = true;

			window.setTimeout(function () {
				if (!isRecording)
					return;
				try {
					recognition.start();
				} catch (err) {
					speechRestarting = false;
					stopRecording();
				}
			}, 80);
		};
	} else {
		btnSes.disabled = true;
		setStatus('Bu tarayıcıda ses tanıma yok. Notu yazabilirsiniz.');
	}

	btnSes.addEventListener('click', function () {
		if (isRecording)
			stopRecording();
		else
			startRecording();
	});

	if (btnCopy) {
		btnCopy.addEventListener('click', function () {
			var text = resultCode ? resultCode.textContent : '';
			if (!text)
				return;

			if (navigator.clipboard && navigator.clipboard.writeText) {
				navigator.clipboard.writeText(text).then(function () {
					btnCopy.textContent = 'Kopyalandı';
					window.setTimeout(function () {
						btnCopy.textContent = 'Kopyala';
					}, 1400);
				});
				return;
			}

			showError('Kopyalama bu tarayıcıda desteklenmiyor.');
		});
	}

	if (form) {
		form.addEventListener('submit', function (event) {
			event.preventDefault();
			event.stopPropagation();
			var analizBtn = document.getElementById('btn-analiz-et');
			if (analizBtn)
				analizBtn.click();
		});
	}
})();

(function () {
	var analizBtn = document.getElementById('btn-analiz-et');
	var textArea = document.getElementById('gorusme-metni');
	var todoListEl = document.getElementById('todo-list');
	var todoDoneList = document.getElementById('todo-done-list');
	var todoEmptyEl = document.getElementById('todo-empty');
	var GECERSIZ_YANIT = 'Sunucudan geçersiz veya boş yanıt alındı';
	var resultBoxEl = document.getElementById('analiz-sonuc');
	var resultCodeEl = document.getElementById('analiz-json');
	var summaryBoxEl = document.getElementById('analiz-ozet');
	var loadingEl = document.getElementById('analiz-yukleniyor');
	var errorBoxEl = document.getElementById('analiz-hata');
	var errorTextEl = document.getElementById('analiz-hata-metni');

	if (!analizBtn) {
		console.error('HATA OLUŞTU: #btn-analiz-et bulunamadı');
	}

	var analizDevamEdiyor = false;
	var isLoading = false;
	var analizBtnVarsayilan = 'Yapay Zeka ile Analiz Et';
	if (analizBtn && analizBtn.getAttribute('data-label'))
		analizBtnVarsayilan = analizBtn.getAttribute('data-label');
	else if (analizBtn && String(analizBtn.textContent || '').trim())
		analizBtnVarsayilan = String(analizBtn.textContent).trim();

	function setAnalizBusy(busy) {
		isLoading = !!busy;
		analizDevamEdiyor = isLoading;
		window.analizDevamEdiyor = isLoading;

		if (analizBtn) {
			analizBtn.disabled = isLoading;
			analizBtn.classList.toggle('is-busy', isLoading);
			analizBtn.setAttribute('aria-busy', isLoading ? 'true' : 'false');
			analizBtn.innerHTML = isLoading
				? '<span class="crm-spinner crm-spinner-inline" aria-hidden="true"></span>Analiz Ediliyor...'
				: analizBtnVarsayilan;
		}

		if (loadingEl) {
			loadingEl.hidden = !isLoading;
			loadingEl.style.display = isLoading ? '' : 'none';
		}
	}

	function analizHataGoster(error) {
		var msg = (error && error.message) ? error.message : 'Analiz sırasında hata oluştu.';
		if (/429|quota|kota|ResourceExhausted/i.test(msg))
			msg = 'API kotası doldu. Lütfen bir dakika bekleyip tekrar deneyin.';
		if (errorTextEl)
			errorTextEl.textContent = msg;
		if (errorBoxEl)
			errorBoxEl.hidden = false;
		console.error('HATA OLUŞTU:', error);
	}

	function kisaGorevMetni(item) {
		var metin = '';
		if (typeof item === 'string')
			metin = item;
		else if (item && typeof item === 'object')
			metin = String(item.baslik || item.title || item.metin || '');
		else
			return '';
		metin = metin.replace(/\s+/g, ' ').trim();
		if (!metin)
			return '';
		if (metin.split(' ').length > 20)
			return '';
		return metin;
	}

	function gorevKaynagi(item, fallback) {
		if (!item || typeof item !== 'object')
			return fallback || 'AI Tespit Etti';
		if (item.kaynak === 'manual' || item.kaynak === 'manuel' || item.source === 'manual')
			return 'Manuel';
		return fallback || 'AI Tespit Etti';
	}

	function apiGorevindenTodo(gorev) {
		if (!gorev || typeof gorev !== 'object')
			return null;
		var due = gorev.due_date || gorev.tarih || '';
		return {
			title: String(gorev.baslik || gorev.title || gorev.description || '').trim(),
			due: due ? String(due).slice(0, 10) : '',
			source: (gorev.kaynak === 'manuel' || gorev.kaynak === 'manual') ? 'manual' : 'ai',
			label: (gorev.kaynak === 'manuel' || gorev.kaynak === 'manual') ? 'Manuel' : 'AI Tespit Etti',
			kurum: gorev.kurum_adi || '',
			dbId: gorev.id,
			assigned_user_id: gorev.assigned_user_id,
			assigned_user_name: gorev.assigned_user_name,
			user_id: gorev.user_id,
			olusturan_adi: gorev.olusturan_adi || '',
			company_id: gorev.company_id,
			done: !!gorev.tamamlandi
		};
	}

	function gorevleriListeyeEkle(gorevler, label) {
		var eklendi = 0;
		var i, metin, extra, kayitli;
		if (!Array.isArray(gorevler))
			return 0;
		for (i = 0; i < gorevler.length; i++) {
			kayitli = !!(gorevler[i] && gorevler[i].id);
			metin = kayitli
				? String((gorevler[i].baslik || gorevler[i].title || '')).replace(/\s+/g, ' ').trim()
				: kisaGorevMetni(gorevler[i]);
			if (!metin)
				continue;
			extra = {
				label: gorevKaynagi(gorevler[i], label || 'AI Tespit Etti'),
				kurum: (gorevler[i] && gorevler[i].kurum_adi) || '',
				assigned_user_id: gorevler[i] && gorevler[i].assigned_user_id,
				assigned_user_name: gorevler[i] && gorevler[i].assigned_user_name,
				user_id: gorevler[i] && gorevler[i].user_id,
				company_id: gorevler[i] && gorevler[i].company_id,
				dbId: gorevler[i] && gorevler[i].id,
				done: !!(gorevler[i] && gorevler[i].tamamlandi),
				due: gorevler[i] && (gorevler[i].due_date || gorevler[i].tarih)
					? String(gorevler[i].due_date || gorevler[i].tarih).slice(0, 10)
					: '',
				source: (gorevler[i] && (gorevler[i].kaynak === 'manuel' || gorevler[i].kaynak === 'manual'))
					? 'manual'
					: 'ai'
			};
			if (typeof window.ekleAiGorev === 'function') {
				if (window.ekleAiGorev(metin, extra))
					eklendi++;
			} else if (todoListEl) {
				// NOT: "AI Tespit Etti" rozeti kaldırıldı (bkz. createGorevLi);
				// bu yedek (fallback) yolda da rozet elemanı hiç eklenmiyor,
				// böylece .crm-todo-item flex düzeni bozulmadan sadeleşiyor.
				var li = document.createElement('li');
				li.className = 'crm-todo-item is-ai';
				li.innerHTML =
					'<div class="crm-todo-body">' +
						'<span class="crm-todo-title"></span>' +
						'<span class="crm-todo-meta"></span>' +
					'</div>';
				li.querySelector('.crm-todo-title').textContent = metin;
				li.querySelector('.crm-todo-meta').textContent = new Date().toLocaleDateString('tr-TR');
				todoListEl.appendChild(li);
				eklendi++;
			}
		}
		if (eklendi && todoEmptyEl)
			todoEmptyEl.style.display = 'none';
		else if (todoEmptyEl && todoListEl && !todoListEl.children.length && (!todoDoneList || !todoDoneList.children.length)) {
			todoEmptyEl.textContent = 'Henüz görev yok';
			todoEmptyEl.style.display = '';
		}
		return eklendi;
	}

	function todoListesiBosMu() {
		var aktif = todoListEl ? todoListEl.children.length : 0;
		var biten = todoDoneList ? todoDoneList.children.length : 0;
		return (aktif + biten) === 0;
	}

	(function loadDbGorevler() {
		if (todoEmptyEl) {
			todoEmptyEl.textContent = 'Görevler yükleniyor...';
			todoEmptyEl.style.display = '';
		}
		if (typeof window.crmGorevleriYenile === 'function') {
			window.crmGorevleriYenile()
				.then(function () {
					if (typeof window.yoneticiNotlariniYukle === 'function')
						window.yoneticiNotlariniYukle();
					if (todoEmptyEl && todoListesiBosMu()) {
						todoEmptyEl.textContent = 'Henüz görev yok';
						todoEmptyEl.style.display = '';
					}
				})
				.catch(function (error) {
					console.error('HATA OLUŞTU:', error);
					if (todoEmptyEl && todoListesiBosMu()) {
						todoEmptyEl.textContent = 'Henüz görev yok';
						todoEmptyEl.style.display = '';
					}
				});
			return;
		}
		var fetchJsonFn = typeof window.fetchJson === 'function'
			? window.fetchJson
			: function (url, options) {
				return fetch(url, options).then(function (response) {
					return response.text().then(function (raw) {
						if (!response.ok || !String(raw || '').trim())
							throw new Error(GECERSIZ_YANIT);
						try {
							return JSON.parse(raw);
						} catch (err) {
							throw new Error(GECERSIZ_YANIT);
						}
					});
				});
			};
		fetchJsonFn(CRM_API + '/api/gorevler', { headers: { 'Accept': 'application/json' } })
			.then(function (data) {
				console.log('Veritabanı görevleri:', data);
				var gorevler = data && Array.isArray(data.gorevler) ? data.gorevler : [];
				if (gorevler.length)
					gorevleriListeyeEkle(gorevler, 'AI Tespit Etti');
				if (typeof window.yoneticiNotlariniYukle === 'function')
					window.yoneticiNotlariniYukle();
			})
			.then(function () {
				if (todoEmptyEl && todoListesiBosMu()) {
					todoEmptyEl.textContent = 'Henüz görev yok';
					todoEmptyEl.style.display = '';
				}
			})
			.catch(function (error) {
				console.error('HATA OLUŞTU:', error);
				if (todoEmptyEl && todoListesiBosMu()) {
					todoEmptyEl.textContent = 'Henüz görev yok';
					todoEmptyEl.style.display = '';
				}
			});
	})();

	async function calistirAnaliz() {
		if (isLoading || analizDevamEdiyor)
			return;

		console.log('1. Butona tıklandı, analiz başlıyor...');

		var textInput = textArea ? String(textArea.value || '').trim() : '';
		console.log('2. Gönderilen Metin:', textInput);

		if (!textInput) {
			analizHataGoster(new Error('Önce görüşme notu girin veya ses kaydı alın.'));
			if (textArea) textArea.focus();
			return;
		}

		if (errorBoxEl)
			errorBoxEl.hidden = true;

		setAnalizBusy(true);

		try {
			var response = await fetch(CRM_API + '/api/analiz', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'Accept': 'application/json'
				},
				body: JSON.stringify({ metin: textInput })
			});

			var raw = await response.text();
			var parseFn = window.jsonGuvenliParse;
			var hataFn = window.hataMesajiniAl;
			var data;

			try {
				if (typeof parseFn === 'function')
					data = parseFn(raw);
				else if (!String(raw || '').trim())
					throw new Error(GECERSIZ_YANIT);
				else
					data = JSON.parse(raw);
			} catch (parseErr) {
				if (!response.ok) {
					if (response.status === 429)
						throw new Error('API kotası doldu. Lütfen bir dakika bekleyip tekrar deneyin.');
					var detay = typeof hataFn === 'function' ? hataFn({}, response.status) : '';
					try {
						var errData = raw ? JSON.parse(raw) : null;
						if (errData && typeof hataFn === 'function')
							detay = hataFn(errData, response.status);
					} catch (ignore) {}
					throw new Error(detay || ('Sunucu hatası (HTTP ' + response.status + ').'));
				}
				throw new Error(GECERSIZ_YANIT);
			}

			console.log('3. Backend\'den Gelen Cevap:', data);

			if (!response.ok) {
				if (response.status === 429)
					throw new Error('API kotası doldu. Lütfen bir dakika bekleyip tekrar deneyin.');
				throw new Error(typeof hataFn === 'function' ? hataFn(data, response.status) : ('HTTP ' + response.status));
			}

			if (typeof fillGlance === 'function')
				fillGlance(data);
			else if (summaryBoxEl)
				summaryBoxEl.hidden = false;

			gorevleriListeyeEkle(
				(data && Array.isArray(data.gorevler)) ? data.gorevler : [],
				'AI Tespit Etti'
			);

			if (typeof window.loadGlobalStats === 'function')
				window.loadGlobalStats();
			if (typeof window.yukleKayitTablosu === 'function')
				window.yukleKayitTablosu();

			// Analiz kaydı oluşunca detay çekmecesini hemen aç; kart tıklaması
			// yedek kalsın. analiz_id yoksa eski davranış: özete kaydır.
			var detayAcildi = typeof ozetKartindanDetayAc === 'function'
				? ozetKartindanDetayAc()
				: false;
			if (!detayAcildi && summaryBoxEl)
				summaryBoxEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
		} catch (error) {
			analizHataGoster(error);
		} finally {
			setAnalizBusy(false);
		}
	}

	window.calistirAnaliz = calistirAnaliz;

	if (!analizBtn)
		return;

	setAnalizBusy(false);

	analizBtn.addEventListener('click', function (e) {
		e.preventDefault();
		e.stopPropagation();
		if (isLoading || analizDevamEdiyor)
			return;
		calistirAnaliz();
	});
})();

(function () {
	'use strict';

	var API_BASE = CRM_API;
	var tbody = document.getElementById('kayit-tbody');
	var veritabaniTbody = document.getElementById('veritabani-tbody');
	var veritabaniThead = document.getElementById('veritabani-thead');
	var dbTabloListesi = document.getElementById('db-tablo-listesi');
	var dbTabloOzet = document.getElementById('db-tablo-ozet');
	var seciliTabloAdi = '';
	var seciliTabloKolonlar = [];
	var seciliTabloKayitlar = [];
	var dbEditModal = document.getElementById('db-edit-modal');
	var dbEditForm = document.getElementById('db-edit-form');
	var dbEditFields = document.getElementById('db-edit-fields');
	var dbEditHata = document.getElementById('db-edit-hata');
	var dbEditKayitId = null;
	var modal = document.getElementById('kayit-modal');
	var form = document.getElementById('kayit-formu');
	var titleEl = document.getElementById('kayit-modal-title');
	var idEl = document.getElementById('kayit-id');
	var kurumEl = document.getElementById('kayit-kurum');
	var urunEl = document.getElementById('kayit-urun');
	var kayitUrunOrijinalAdlar = [];
	var kayitUrunOrijinalKodlar = [];
	var kayitUrunIlkDeger = '';
	var abonelikTipiEl = document.getElementById('kayit-abonelik-tipi');
	var durumEl = document.getElementById('kayit-durum');
	var notEl = document.getElementById('kayit-not');
	var hataEl = document.getElementById('kayit-form-hata');
	var kaydetBtn = document.getElementById('kayit-kaydet');
	var gorevlerWrap = document.getElementById('kayit-gorevler-wrap');
	var gorevlerList = document.getElementById('kayit-gorevler-list');
	var gorevlerBos = document.getElementById('kayit-gorevler-bos');
	var drawer = document.getElementById('kayit-drawer');
	var drawerKurum = document.getElementById('drawer-kurum');
	var drawerTarih = document.getElementById('drawer-tarih');
	var drawerDurum = document.getElementById('drawer-durum');
	var drawerSurec = document.getElementById('drawer-surec');
	var drawerUrunler = document.getElementById('drawer-urunler');
	var drawerNot = document.getElementById('drawer-not');
	var drawerIcerik = document.getElementById('drawer-icerik');
	var drawerYukle = document.getElementById('drawer-yukle');
	var drawerHata = document.getElementById('drawer-hata');
	var drawerHataMetni = document.getElementById('drawer-hata-metni');
	var drawerDuzenle = document.getElementById('drawer-duzenle');
	var drawerSil = document.getElementById('drawer-sil');
	var dashKartlar = document.getElementById('dash-kartlar');
	var notlarKartlar = document.getElementById('notlar-kartlar');
	var sonKayitlar = [];
	var kurumKartlar = document.getElementById('kurum-kartlar');
	var gorusmeKartlar = document.getElementById('gorusme-kartlar');
	var urunTbody = document.getElementById('urun-tbody');
	var acikUrunId = null;
	var kurumListeCache = [];
	var kurumOzetCache = { byId: {}, byAd: {} };
	var tabloSorgu = {
		gorusme: { q: '', sort: 'tarih', dir: 'desc', durum: '', surec: '', urun: '' },
		kurum: { q: '', sort: 'ad', dir: 'asc', durum: '', surec: '', urun: '' },
		urun: { q: '', sort: 'name', dir: 'asc', company: '' },
		not: { q: '' },
		db: { q: '', sort: '', dir: 'asc', filtre: {} }
	};

	var kolonFiltreHedef = null;
	var kolonFiltrePopover = null;

	function benzersizSirali(degerler) {
		var set = {};
		var liste = [];
		(degerler || []).forEach(function (v) {
			v = String(v == null ? '' : v).trim();
			if (!v || v === '—') return;
			if (set[v]) return;
			set[v] = true;
			liste.push(v);
		});
		liste.sort(function (a, b) {
			return String(a).localeCompare(String(b), 'tr', { numeric: true, sensitivity: 'base' });
		});
		return liste;
	}

	function kurumKolonDegerleri(kolon) {
		var ozet = kurumOzetCache || { byId: {}, byAd: {} };
		var ham = kurumListeCache || [];
		if (kolon === 'durum') {
			return benzersizSirali(ham.map(function (k) {
				return kurumSatirOzet(k, ozet).k.durum;
			}));
		}
		if (kolon === 'surec') {
			return benzersizSirali(ham.map(function (k) {
				var o = kurumSatirOzet(k, ozet);
				return surecTipiSec(o.k.surec_tipi || o.k.abonelik_tipi);
			}));
		}
		if (kolon === 'urun') {
			var urunler = [];
			ham.forEach(function (k) {
				var o = kurumSatirOzet(k, ozet);
				String(o.urunler || '').split(',').forEach(function (u) {
					u = u.trim();
					if (u && u !== '—') urunler.push(u);
				});
			});
			return benzersizSirali(urunler);
		}
		return [];
	}

	function katalogUrunAdlari() {
		return benzersizSirali((urunlerCache || []).map(function (u) {
			return String((u && (u.name || u.code)) || '').trim();
		}).filter(Boolean));
	}

	function gorusmeUrunDegerleri() {
		var katalog = katalogUrunAdlari();
		if (katalog.length)
			return katalog;
		var urunler = [];
		(sonKayitlar || []).forEach(function (k) {
			if (Array.isArray(k.ilgilenilen_urunler))
				k.ilgilenilen_urunler.forEach(function (u) { if (u) urunler.push(u); });
			else if (k.urun_adi) urunler.push(k.urun_adi);
		});
		return benzersizSirali(urunler);
	}

	function gorusmeUrunFiltreSelectGuncelle() {
		var sel = document.getElementById('gorusme-filtre-urun');
		if (!sel) return;
		var mevcut = sel.value || '';
		var degerler = gorusmeUrunDegerleri();
		sel.innerHTML = '<option value="">Tüm ürünler</option>' +
			degerler.map(function (d) {
				return '<option value="' + kacis(d) + '">' + kacis(d) + '</option>';
			}).join('');
		if (mevcut && degerler.indexOf(mevcut) >= 0)
			sel.value = mevcut;
	}

	function urunSirketDegerleri() {
		return benzersizSirali((urunlerCache || []).map(function (u) { return u.company_name; }));
	}

	function dbKolonFiltrelenebilirMi(kolon, kayitlar) {
		if (!kolon || !kayitlar || kayitlar.length < 2)
			return false;
		var set = {};
		kayitlar.forEach(function (r) {
			var v = hucreYaz(r[kolon]);
			if (v && v !== '—')
				set[v] = true;
		});
		var n = Object.keys(set).length;
		return n > 1 && n <= 28;
	}

	function dbKolonDegerleri(kolon) {
		return benzersizSirali((seciliTabloKayitlar || []).map(function (r) { return hucreYaz(r[kolon]); }));
	}

	function kolonFiltrePopoverKapat() {
		if (kolonFiltrePopover)
			kolonFiltrePopover.hidden = true;
		kolonFiltreHedef = null;
	}

	function kolonFiltreMenuAc(btn, baslik, degerler, secili, secFn) {
		if (!kolonFiltrePopover)
			kolonFiltrePopover = document.getElementById('crm-col-filter-popover');
		if (!kolonFiltrePopover || !btn)
			return;
		var titleEl = kolonFiltrePopover.querySelector('.crm-col-filter-title');
		var listEl = kolonFiltrePopover.querySelector('.crm-col-filter-list');
		if (titleEl)
			titleEl.textContent = baslik;
		if (!listEl)
			return;
		var html = '<button type="button" class="crm-col-filter-opt' + (!secili ? ' is-active' : '') + '" data-val="">Tümü</button>';
		(degerler || []).forEach(function (d) {
			var aktif = String(secili) === String(d);
			html += '<button type="button" class="crm-col-filter-opt' + (aktif ? ' is-active' : '') + '" data-val="' +
				kacis(d) + '">' + kacis(d) + '</button>';
		});
		listEl.innerHTML = html;
		kolonFiltreHedef = btn;
		btn.setAttribute('aria-expanded', 'true');
		kolonFiltrePopover.hidden = false;
		var rect = btn.getBoundingClientRect();
		var popW = 220;
		var left = Math.min(Math.max(8, rect.left), window.innerWidth - popW - 8);
		kolonFiltrePopover.style.position = 'fixed';
		kolonFiltrePopover.style.top = (rect.bottom + 6) + 'px';
		kolonFiltrePopover.style.left = left + 'px';
		listEl.onclick = function (e) {
			var opt = e.target.closest ? e.target.closest('.crm-col-filter-opt') : null;
			if (!opt) return;
			e.preventDefault();
			secFn(opt.getAttribute('data-val') || '');
			kolonFiltrePopoverKapat();
		};
	}

	function kurumSatirFiltreUygun(row, st) {
		if (st.durum && String(row.o.k.durum || '') !== st.durum)
			return false;
		if (st.surec) {
			var surec = surecTipiSec(row.o.k.surec_tipi || row.o.k.abonelik_tipi);
			if (surec !== st.surec) return false;
		}
		if (st.urun && String(row.o.urunler || '').indexOf(st.urun) < 0)
			return false;
		return true;
	}

	function gorusmeKayitFiltreUygun(k, st) {
		if (st.durum && String(k.durum || '') !== st.durum)
			return false;
		if (st.surec) {
			var surec = surecTipiSec(k.surec_tipi || k.abonelik_tipi);
			if (surec !== st.surec) return false;
		}
		if (st.urun) {
			var hedef = String(st.urun).toLocaleLowerCase('tr-TR');
			var adlar = Array.isArray(k.ilgilenilen_urunler) ? k.ilgilenilen_urunler.slice() : [];
			if (k.urun_adi) adlar.push(k.urun_adi);
			if (k.urun_kodu) adlar.push(k.urun_kodu);
			var eslesti = adlar.some(function (u) {
				return String(u || '').toLocaleLowerCase('tr-TR') === hedef;
			});
			if (!eslesti && String(adlar.join(' ')).toLocaleLowerCase('tr-TR').indexOf(hedef) < 0)
				return false;
		}
		return true;
	}

	function yazSonuc(id, gorunen, toplam) {
		var el = document.getElementById(id);
		if (!el) return;
		if (!toplam)
			el.textContent = '';
		else if (gorunen === toplam)
			el.textContent = toplam + ' kayıt';
		else
			el.textContent = gorunen + ' / ' + toplam + ' kayıt';
	}
	var urunlerCache = [];
	var kayitCache = {};
	var drawerKayitId = null;

	if (!tbody)
		return;

	function jsonAl(response, raw) {
		if (!String(raw || '').trim())
			throw new Error('Sunucudan geçersiz veya boş yanıt alındı');
		var data = JSON.parse(raw);
		if (!response.ok) {
			var detay = data && data.detail;
			if (Array.isArray(detay))
				detay = detay.map(function (x) { return x.msg || JSON.stringify(x); }).join(' ');
			throw new Error(detay || (data && data.hata) || ('HTTP ' + response.status));
		}
		if (data && data.hata)
			throw new Error(String(data.hata));
		return data;
	}

	function apiGet(yol) {
		return fetch(API_BASE + yol, { headers: { Accept: 'application/json' } })
			.then(function (r) { return r.text().then(function (raw) { return jsonAl(r, raw); }); });
	}

	function apiPut(yol, govde) {
		return fetch(API_BASE + yol, {
			method: 'PUT',
			headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
			body: JSON.stringify(govde || {})
		}).then(function (r) { return r.text().then(function (raw) { return jsonAl(r, raw); }); });
	}

	function apiPost(yol, govde) {
		return fetch(API_BASE + yol, {
			method: 'POST',
			headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
			body: JSON.stringify(govde || {})
		}).then(function (r) { return r.text().then(function (raw) { return jsonAl(r, raw); }); });
	}

	function apiDelete(yol) {
		return fetch(API_BASE + yol, {
			method: 'DELETE',
			headers: { Accept: 'application/json' }
		}).then(function (r) { return r.text().then(function (raw) { return jsonAl(r, raw); }); });
	}

	function tarihYaz(iso) {
		if (!iso) return '—';
		var d = new Date(iso);
		if (isNaN(d.getTime())) return iso;
		return d.toLocaleString('tr-TR', { dateStyle: 'short', timeStyle: 'short' });
	}

	function durumSinif(durum) {
		var d = String(durum || '').toLowerCase();
		if (d.indexOf('karma') >= 0) return 'is-karma';
		if (d.indexOf('olumlu') >= 0) return 'is-positive';
		if (d.indexOf('olumsuz') >= 0) return 'is-negative';
		return 'is-pending';
	}

	function durumSec(deger) {
		var d = String(deger || '').toLowerCase();
		if (d.indexOf('karma') >= 0) return 'Karma';
		if (d.indexOf('olumsuz') >= 0) return 'Olumsuz';
		if (d.indexOf('olumlu') >= 0) return 'Olumlu';
		return 'Beklemede';
	}

	function surecTipiSec(deger) {
		var d = String(deger || '').toLowerCase();
		if (/deneme|demo|trial|pilot/.test(d)) return 'Deneme';
		if (/abone|sat[iı]n|lisans|kontrat|s[oö]zle[sş]me/.test(d)) return 'Abonelik';
		return 'Hiçbiri';
	}

	function surecTipiSinif(deger) {
		var v = surecTipiSec(deger);
		if (v === 'Deneme') return 'is-deneme';
		if (v === 'Abonelik') return 'is-abonelik';
		return 'is-hicbiri';
	}

	function abonelikTipiSec(deger) {
		return surecTipiSec(deger);
	}

	function abonelikTipiSinif(deger) {
		return surecTipiSinif(deger);
	}

	function kacis(metin) {
		return String(metin == null ? '' : metin)
			.replace(/&/g, '&amp;')
			.replace(/</g, '&lt;')
			.replace(/>/g, '&gt;')
			.replace(/"/g, '&quot;');
	}

	function hucreYaz(deger) {
		if (deger == null || deger === '')
			return '—';
		if (typeof deger === 'boolean')
			return deger ? 'true' : 'false';
		return String(deger);
	}

	var dbTabloMeta = { baslik: '', ad: '' };
	var dbKolonImzasi = '';

	function renderHamTablo(data) {
		if (!veritabaniTbody)
			return;
		if (data) {
			seciliTabloKolonlar = ((data.kolonlar) || []).slice();
			seciliTabloKayitlar = ((data.kayitlar) || []).slice();
			dbTabloMeta = { baslik: data.baslik || '', ad: data.ad || '' };
		}
		renderDbGorunum();
	}

	function renderDbBaslik() {
		if (!veritabaniThead)
			return;
		var kolonlar = seciliTabloKolonlar;
		var isAdmin = window.Auth && window.Auth.isAdmin && window.Auth.isAdmin();
		var imza = kolonlar.join('\0');
		if (!kolonlar.length) {
			veritabaniThead.innerHTML = '';
			dbKolonImzasi = '';
			return;
		}
		if (imza === dbKolonImzasi && veritabaniThead.querySelector('.crm-sort-btn'))
			return;
		dbKolonImzasi = imza;
		var basliklar = kolonlar.map(function (k) {
			var filtre = dbKolonFiltrelenebilirMi(k, seciliTabloKayitlar);
			var filtreAttr = filtre ? (' data-col-filter="' + kacis(k) + '"') : '';
			var caret = filtre ? ' <span class="crm-filter-caret" aria-hidden="true">▾</span>' : '';
			return '<th><button type="button" class="crm-sort-btn' + (filtre ? ' has-col-filter' : '') + '" data-sort="' + kacis(k) + '"' + filtreAttr + '>' +
				kacis(k) + caret + ' <span class="crm-sort-icon">↕</span></button></th>';
		});
		if (isAdmin)
			basliklar.push('<th class="crm-db-actions-col">İşlem</th>');
		veritabaniThead.innerHTML = '<tr>' + basliklar.join('') + '</tr>';
	}

	function dbHucreKarsilastir(a, b, dir) {
		var Q = window.CrmQuery;
		if (!Q) return 0;
		if (a != null && b != null && a !== '' && b !== '' &&
			!isNaN(a) && !isNaN(b) && isFinite(Number(a)) && isFinite(Number(b)))
			return Q.cmp(Number(a), Number(b), dir);
		return Q.cmp(a, b, dir);
	}

	function renderDbGorunum() {
		if (!veritabaniTbody)
			return;
		var Q = window.CrmQuery;
		var kolonlar = seciliTabloKolonlar;
		var kayitlar = seciliTabloKayitlar;
		var st = tabloSorgu.db;
		var isAdmin = window.Auth && window.Auth.isAdmin && window.Auth.isAdmin();
		var colCount = kolonlar.length + (isAdmin ? 1 : 0);
		renderDbBaslik();
		var liste = kayitlar.map(function (satir, index) {
			return { satir: satir, index: index };
		});
		if (Q && st.q) {
			liste = liste.filter(function (row) {
				var parts = kolonlar.map(function (k) { return hucreYaz(row.satir[k]); });
				return Q.match(st.q, parts);
			});
		}
		if (st.filtre) {
			Object.keys(st.filtre).forEach(function (kol) {
				var fv = st.filtre[kol];
				if (!fv) return;
				liste = liste.filter(function (row) {
					return hucreYaz(row.satir[kol]) === fv;
				});
			});
		}
		if (Q && st.sort) {
			liste.sort(function (a, b) {
				return dbHucreKarsilastir(a.satir[st.sort], b.satir[st.sort], st.dir);
			});
		}
		if (Q) {
			var dbTablo = document.getElementById('veritabani-tablosu');
			if (dbTablo) {
				Q.paintSort(dbTablo, st);
				Q.paintColFilter(dbTablo, st, []);
			}
		}
		yazSonuc('db-sonuc', liste.length, kayitlar.length);
		if (dbTabloOzet) {
			var baslik = dbTabloMeta.baslik || dbTabloMeta.ad || 'Tablo';
			dbTabloOzet.textContent = kayitlar.length
				? (baslik + ' · ' + (liste.length === kayitlar.length
					? (kayitlar.length + ' kayıt')
					: (liste.length + ' / ' + kayitlar.length + ' kayıt')))
				: (baslik + ' · 0 kayıt');
		}
		if (!kolonlar.length) {
			veritabaniTbody.innerHTML = '<tr><td>Kolon yok.</td></tr>';
			return;
		}
		if (!kayitlar.length) {
			veritabaniTbody.innerHTML = '<tr><td colspan="' + colCount + '">Bu tabloda kayıt yok.</td></tr>';
			return;
		}
		if (!liste.length) {
			veritabaniTbody.innerHTML = '<tr><td colspan="' + colCount + '">Aramayla eşleşen kayıt yok.</td></tr>';
			return;
		}
		veritabaniTbody.innerHTML = liste.map(function (row) {
			var satir = row.satir;
			var hucreler = kolonlar.map(function (k) {
				var deger = hucreYaz(satir[k]);
				return '<td class="crm-note-cell" title="' + kacis(deger) + '">' + kacis(deger) + '</td>';
			}).join('');
			var islem = '';
			if (isAdmin && satir.id != null)
				islem = '<td class="crm-db-actions-col"><button type="button" class="button small crm-db-edit-btn" data-row-index="' + row.index + '">Düzenle</button></td>';
			else if (isAdmin)
				islem = '<td class="crm-db-actions-col">—</td>';
			return '<tr>' + hucreler + islem + '</tr>';
		}).join('');
	}

	function dbEditModalKapat() {
		if (dbEditModal) dbEditModal.hidden = true;
		dbEditKayitId = null;
		if (dbEditFields) dbEditFields.innerHTML = '';
		if (dbEditHata) dbEditHata.hidden = true;
	}

	function dbEditModalAc(satir) {
		if (!dbEditModal || !dbEditFields || !satir)
			return;
		dbEditKayitId = satir.id;
		var duzenlenebilir = seciliTabloKolonlar.filter(function (k) {
			return k !== 'id' && k !== 'sifre_hash' && k !== 'created_at';
		});
		dbEditFields.innerHTML = duzenlenebilir.map(function (k) {
			var deger = satir[k];
			var val = deger == null ? '' : String(deger);
			return '<label><span class="crm-field-label">' + kacis(k) + '</span>' +
				'<input type="text" name="' + kacis(k) + '" value="' + kacis(val) + '" data-kolon="' + kacis(k) + '" /></label>';
		}).join('');
		if (dbEditHata) dbEditHata.hidden = true;
		dbEditModal.hidden = false;
	}

	function dbEditKaydet(event) {
		event.preventDefault();
		if (!seciliTabloAdi || dbEditKayitId == null || !dbEditForm)
			return;
		var govde = {};
		Array.prototype.forEach.call(dbEditForm.querySelectorAll('[data-kolon]'), function (input) {
			var kolon = input.getAttribute('data-kolon');
			if (!kolon) return;
			var ham = input.value;
			if (ham === 'true') govde[kolon] = true;
			else if (ham === 'false') govde[kolon] = false;
			else if (ham !== '' && !isNaN(ham) && /^-?\d+(\.\d+)?$/.test(ham)) govde[kolon] = Number(ham);
			else govde[kolon] = ham;
		});
		if (dbEditHata) dbEditHata.hidden = true;
		apiPut('/api/tablolar/' + encodeURIComponent(seciliTabloAdi) + '/' + encodeURIComponent(dbEditKayitId), govde)
			.then(function () {
				dbEditModalKapat();
				if (typeof window.gosterToast === 'function')
					window.gosterToast('Kayıt güncellendi', 'ok');
				yukleTabloSatirlari(seciliTabloAdi);
			})
			.catch(function (err) {
				if (dbEditHata) {
					dbEditHata.hidden = false;
					dbEditHata.textContent = err.message || 'Kayıt güncellenemedi';
				}
			});
	}

	function yukleTabloSatirlari(ad) {
		if (!ad)
			return;
		seciliTabloAdi = ad;
		tabloSorgu.db = { q: '', sort: '', dir: 'asc', filtre: {} };
		dbKolonImzasi = '';
		var dbArama = document.getElementById('db-arama');
		if (dbArama)
			dbArama.value = '';
		if (dbTabloListesi) {
			Array.prototype.forEach.call(dbTabloListesi.querySelectorAll('.crm-db-tab'), function (btn) {
				btn.classList.toggle('is-active', btn.getAttribute('data-tablo') === ad);
			});
		}
		if (veritabaniTbody)
			veritabaniTbody.innerHTML = '<tr><td>Yükleniyor...</td></tr>';
		return apiGet('/api/tablolar/' + encodeURIComponent(ad))
			.then(renderHamTablo)
			.catch(function () {
				if (veritabaniTbody)
					veritabaniTbody.innerHTML = '<tr><td>Tablo yüklenemedi. API çalışıyor mu?</td></tr>';
			});
	}

	function yukleVeritabaniTablolari() {
		return apiGet('/api/tablolar')
			.then(function (data) {
				var tablolar = (data && data.tablolar) || [];
				if (!dbTabloListesi)
					return;
				if (!tablolar.length) {
					dbTabloListesi.innerHTML = '<span>Tablo listesi boş.</span>';
					return;
				}
				dbTabloListesi.innerHTML = tablolar.map(function (t) {
					return '<button type="button" class="crm-db-tab" data-tablo="' + kacis(t.ad) + '">' +
						kacis(t.baslik || t.ad) +
						'<small>' + kacis(t.ad) + '</small>' +
					'</button>';
				}).join('');
				var ilk = seciliTabloAdi && tablolar.some(function (t) { return t.ad === seciliTabloAdi; })
					? seciliTabloAdi
					: tablolar[0].ad;
				yukleTabloSatirlari(ilk);
			})
			.catch(function () {
				if (dbTabloListesi)
					dbTabloListesi.innerHTML = '<span>Tablolar alınamadı.</span>';
			});
	}

	if (dbTabloListesi) {
		dbTabloListesi.addEventListener('click', function (e) {
			var btn = e.target && e.target.closest ? e.target.closest('.crm-db-tab') : null;
			if (btn)
				yukleTabloSatirlari(btn.getAttribute('data-tablo'));
		});
	}

	function notOzetAl(k) {
		return String((k && (k.not_icerigi || k.raw_transcript)) || '').replace(/\s+/g, ' ').trim();
	}

	function renderNotlarKartlar(kayitlar) {
		if (!notlarKartlar)
			return;
		var Q = window.CrmQuery;
		var q = tabloSorgu.not.q;
		var kaynak = Array.isArray(kayitlar) ? kayitlar : sonKayitlar;
		var liste = (kaynak || []).filter(function (k) {
			return !Q || Q.match(q, [k.kurum_adi, notOzetAl(k), k.durum, k.urun_adi]);
		});
		yazSonuc('notlar-sonuc', liste.length, (kaynak || []).length);
		if (!liste.length) {
			notlarKartlar.innerHTML = '<p class="crm-todo-empty">' +
				(q ? 'Aramayla eşleşen not yok.' : 'Henüz not yok. Sol menüden <strong>Not Ekle</strong> ile ilk notunuzu oluşturun.') +
			'</p>';
			return;
		}
		var adminGorunumu = window.Auth && window.Auth.isAdmin && window.Auth.isAdmin();
		notlarKartlar.innerHTML = liste.map(function (k) {
			var urunler = Array.isArray(k.ilgilenilen_urunler) && k.ilgilenilen_urunler.length
				? k.ilgilenilen_urunler.join(', ')
				: (k.urun_adi || '');
			var not = notOzetAl(k);
			var curUser = window.Auth && window.Auth.getUser && window.Auth.getUser();
			var canSil = adminGorunumu || (curUser && k.user_id && String(curUser.id) === String(k.user_id));
			var silBtnHtml = canSil
				? '<button type="button" class="crm-kart-sil-btn" data-action="sil-kart" data-id="' + kacis(String(k.id || '')) + '" title="Görüşmeyi Sil" aria-label="Görüşmeyi Sil"><i class="fas fa-trash-alt"></i></button>'
				: '';
			return '<article class="crm-mini-card crm-not-kart" data-id="' + k.id + '" tabindex="0">' +
				silBtnHtml +
				'<span class="crm-mini-card-date">' + kacis(tarihYaz(k.tarih)) + '</span>' +
				'<p class="crm-mini-card-kurum-etiket">Kurum</p>' +
				'<h4>' + kacis(k.kurum_adi || 'Kurum belirtilmedi') + '</h4>' +
				'<p class="crm-not-snippet">' + kacis(not || 'Not içeriği yok') + '</p>' +
				'<div class="crm-chip-row">' +
					'<span class="crm-badge ' + durumSinif(k.durum) + '">' + kacis(k.durum || '—') + '</span>' +
				'</div>' +
				(urunler ? '<p class="crm-mini-card-meta">' + kacis(urunler) + '</p>' : '') +
			'</article>';
		}).join('');
	}

	function aktifSekmeAl() {
		var h = (window.location.hash || '').replace(/^#/, '').trim();
		return h || 'gorusmeler';
	}

	function notEkleBlokunuTasi(hedefId) {
		var blok = document.getElementById('not-ekle-blok');
		var hedef = document.getElementById(hedefId);
		var notYuva = document.getElementById('notlarim-not-ekle-yuvasi');
		if (!blok || !hedef)
			return;
		if (blok.parentNode !== hedef)
			hedef.appendChild(blok);
		if (notYuva)
			notYuva.hidden = hedef !== notYuva;
	}

	function notEklePanelineGit() {
		var notlarda = aktifSekmeAl() === 'notlarim';
		if (notlarda) {
			notEkleBlokunuTasi('notlarim-not-ekle-yuvasi');
		} else {
			if (typeof window.crmSekmeyiAc === 'function')
				window.crmSekmeyiAc('gorusmeler');
			notEkleBlokunuTasi('dash-not-ekle-yuvasi');
		}
		window.setTimeout(function () {
			var panel = document.getElementById('crm-not-ekle-panel');
			if (panel && panel.scrollIntoView)
				panel.scrollIntoView({ behavior: 'smooth', block: 'start' });
			var textarea = document.getElementById('gorusme-metni');
			if (textarea)
				textarea.focus();
		}, 220);
	}

	function gorusmeKartHtml(k, adminGorunumu) {
		var urunler = Array.isArray(k.ilgilenilen_urunler) && k.ilgilenilen_urunler.length
			? k.ilgilenilen_urunler.join(', ')
			: (k.urun_adi || '');
		var badgeHtml = (adminGorunumu && k.kullanici_adi)
			? '<span class="crm-user-badge"><span class="icon fa-user"></span> ' + kacis(k.kullanici_adi) + '</span>'
			: '';
		var curUser = window.Auth && window.Auth.getUser && window.Auth.getUser();
		var canSil = adminGorunumu || (curUser && k.user_id && String(curUser.id) === String(k.user_id));
		var silBtnHtml = canSil
			? '<button type="button" class="crm-kart-sil-btn" data-action="sil-kart" data-id="' + kacis(String(k.id || '')) + '" title="Görüşmeyi Sil" aria-label="Görüşmeyi Sil"><i class="fas fa-trash-alt"></i></button>'
			: '';
		return '<article class="crm-mini-card crm-gorusme-kart" data-id="' + kacis(String(k.id || '')) + '" tabindex="0">' +
			silBtnHtml +
			'<span class="crm-mini-card-date">' + kacis(tarihYaz(k.tarih)) + '</span>' +
			'<p class="crm-mini-card-kurum-etiket">Kurum</p>' +
			'<h4>' + kacis(k.kurum_adi || 'Kurum belirtilmedi') + '</h4>' +
			'<div class="crm-chip-row">' +
				'<span class="crm-badge ' + durumSinif(k.durum) + '">' + kacis(k.durum || '—') + '</span>' +
				'<span class="crm-chip crm-chip-subscription ' + surecTipiSinif(k.surec_tipi || k.abonelik_tipi) + '">' +
					kacis(surecTipiSec(k.surec_tipi || k.abonelik_tipi)) +
				'</span>' +
			'</div>' +
			(urunler ? '<p class="crm-mini-card-meta">' + kacis(urunler) + '</p>' : '') +
			badgeHtml +
		'</article>';
	}

	function renderDashKartlar(kayitlar) {
		if (!dashKartlar)
			return;
		if (!kayitlar || !kayitlar.length) {
			dashKartlar.innerHTML = '<p class="crm-todo-empty">Henüz görüşme kaydı yok.</p>';
			return;
		}
		var adminGorunumu = window.Auth && window.Auth.isAdmin && window.Auth.isAdmin();
		dashKartlar.innerHTML = kayitlar.slice(0, 12).map(function (k) {
			return gorusmeKartHtml(k, adminGorunumu);
		}).join('');
	}

	function analizOzetHaritasi(kayitlar) {
		var byId = {};
		var byAd = {};
		(kayitlar || []).forEach(function (k) {
			var id = k.kurum_id;
			var adKey = (k.kurum_adi || '').trim().toLocaleLowerCase('tr-TR');
			if (id) {
				if (!byId[id] || String(k.tarih || '') > String(byId[id].tarih || ''))
					byId[id] = k;
			}
			if (adKey) {
				if (!byAd[adKey] || String(k.tarih || '') > String(byAd[adKey].tarih || ''))
					byAd[adKey] = k;
			}
		});
		return { byId: byId, byAd: byAd };
	}

	function gorusmeSiralamaUygula(deger) {
		var v = String(deger || 'tarih-desc');
		var dir = v.slice(-4) === '-asc' ? 'asc' : 'desc';
		var sort = v.replace(/-(asc|desc)$/, '') || 'tarih';
		tabloSorgu.gorusme.sort = sort;
		tabloSorgu.gorusme.dir = dir;
	}

	function renderGorusmeKartlar(kayitlar) {
		if (!gorusmeKartlar)
			return;
		var Q = window.CrmQuery;
		var st = tabloSorgu.gorusme;
		var kaynak = Array.isArray(kayitlar) ? kayitlar : sonKayitlar;
		var adminGorunumu = window.Auth && window.Auth.isAdmin && window.Auth.isAdmin();
		var liste = (kaynak || []).filter(function (k) {
			if (!gorusmeKayitFiltreUygun(k, st))
				return false;
			var urunler = Array.isArray(k.ilgilenilen_urunler) ? k.ilgilenilen_urunler.join(' ') : (k.urun_adi || '');
			return !Q || Q.match(st.q, [k.kurum_adi, urunler, k.durum, k.surec_tipi, k.not_icerigi, tarihYaz(k.tarih)]);
		});
		if (Q) {
			liste.sort(function (a, b) {
				var av, bv;
				if (st.sort === 'kurum') { av = a.kurum_adi; bv = b.kurum_adi; }
				else if (st.sort === 'urun') {
					av = (a.ilgilenilen_urunler || []).join(', ') || a.urun_adi;
					bv = (b.ilgilenilen_urunler || []).join(', ') || b.urun_adi;
				} else if (st.sort === 'durum') { av = a.durum; bv = b.durum; }
				else if (st.sort === 'surec') { av = a.surec_tipi || a.abonelik_tipi; bv = b.surec_tipi || b.abonelik_tipi; }
				else { av = a.tarih || ''; bv = b.tarih || ''; }
				return Q.cmp(av, bv, st.dir);
			});
		}
		yazSonuc('gorusme-sonuc', liste.length, (kaynak || []).length);
		if (!liste.length) {
			gorusmeKartlar.innerHTML = '<p class="crm-todo-empty">' +
				(st.q || st.durum || st.surec || st.urun ? 'Filtreyle eşleşen görüşme yok.' : 'Henüz görüşme kaydı yok.') +
			'</p>';
			return;
		}
		gorusmeKartlar.innerHTML = liste.map(function (k) {
			return gorusmeKartHtml(k, adminGorunumu);
		}).join('');
	}

	function urunAdlariEslesirMi(kayit, urun) {
		var adlar = [];
		if (urun) {
			if (urun.name) adlar.push(String(urun.name).trim().toLocaleLowerCase('tr-TR'));
			if (urun.code) adlar.push(String(urun.code).trim().toLocaleLowerCase('tr-TR'));
		}
		var kayitAdlar = [];
		if (Array.isArray(kayit.ilgilenilen_urunler))
			kayit.ilgilenilen_urunler.forEach(function (a) { kayitAdlar.push(String(a || '').trim().toLocaleLowerCase('tr-TR')); });
		if (kayit.urun_adi) kayitAdlar.push(String(kayit.urun_adi).trim().toLocaleLowerCase('tr-TR'));
		if (kayit.urun_kodu) kayitAdlar.push(String(kayit.urun_kodu).trim().toLocaleLowerCase('tr-TR'));
		return adlar.some(function (ad) {
			return ad && kayitAdlar.indexOf(ad) >= 0;
		});
	}

	function urunKurumOzeti(u) {
		var ilgili = (sonKayitlar || []).filter(function (k) { return urunAdlariEslesirMi(k, u); });
		var kurumlar = [];
		var gorulen = {};
		ilgili.forEach(function (k) {
			var ad = String(k.kurum_adi || '').trim();
			var key = k.kurum_id ? ('id:' + k.kurum_id) : ('ad:' + ad.toLocaleLowerCase('tr-TR'));
			if (!ad || gorulen[key]) return;
			gorulen[key] = true;
			kurumlar.push({ id: k.kurum_id, ad: ad, durum: k.durum });
		});
		return kurumlar;
	}

	function renderUrunTablosu() {
		if (!urunTbody)
			return;
		var Q = window.CrmQuery;
		var st = tabloSorgu.urun;
		var kaynak = (urunlerCache || []).map(function (u) {
			var kurumlar = urunKurumOzeti(u);
			return { u: u, kurumlar: kurumlar, kurumSayisi: kurumlar.length };
		});
		var liste = kaynak.filter(function (row) {
			if (st.company && String(row.u.company_name || '') !== st.company)
				return false;
			return !Q || Q.match(st.q, [row.u.name, row.u.code, row.u.company_name, String(row.kurumSayisi)]);
		});
		if (Q) {
			liste.sort(function (a, b) {
				var av, bv;
				if (st.sort === 'code') { av = a.u.code; bv = b.u.code; }
				else if (st.sort === 'company') { av = a.u.company_name; bv = b.u.company_name; }
				else if (st.sort === 'kurumSayisi') { av = a.kurumSayisi; bv = b.kurumSayisi; }
				else { av = a.u.name; bv = b.u.name; }
				return Q.cmp(av, bv, st.dir);
			});
			Q.paintSort(document.getElementById('urun-tablosu'), st);
			Q.paintColFilter(document.getElementById('urun-tablosu'), st, ['company']);
		}
		yazSonuc('urun-sonuc', liste.length, kaynak.length);
		if (!liste.length) {
			urunTbody.innerHTML = '<tr><td colspan="6">' +
				(st.q || st.company ? 'Filtreyle eşleşen ürün yok.' : 'Henüz ürün kaydı yok.') +
			'</td></tr>';
			return;
		}
		urunTbody.innerHTML = liste.map(function (row) {
			var u = row.u;
			var kurumlar = row.kurumlar;
			var uid = String(u.id || '');
			var acik = acikUrunId === uid;
			var detay = '';
			if (acik) {
				if (!kurumlar.length)
					detay = '<tr class="crm-data-expand"><td colspan="6"><p class="crm-todo-empty">Bu ürünle ilişkilendirilmiş kurum yok.</p></td></tr>';
				else
					detay = '<tr class="crm-data-expand"><td colspan="6"><ul class="crm-pick-list">' +
						kurumlar.map(function (k) {
							return '<li><button type="button" class="crm-data-kurum-link" data-kurum-id="' +
								kacis(String(k.id || '')) + '" data-kurum="' + kacis(k.ad) + '">' +
								kacis(k.ad) + (k.durum ? (' · ' + kacis(k.durum)) : '') +
								'</button></li>';
						}).join('') +
					'</ul></td></tr>';
			}
			return '<tr class="crm-data-row" data-urun-id="' + kacis(uid) + '" tabindex="0">' +
				'<td class="crm-data-caret">' + (acik ? '▾' : '▸') + '</td>' +
				'<td><strong>' + kacis(u.name || '—') + '</strong></td>' +
				'<td>' + kacis(u.code || '—') + '</td>' +
				'<td>' + kacis(u.company_name || '—') + '</td>' +
				'<td>' + row.kurumSayisi + '</td>' +
				'<td><button type="button" class="crm-sil-btn" data-id="' + kacis(uid) + '" data-ad="' + kacis(u.name || '') + '">Sil</button></td>' +
			'</tr>' + detay;
		}).join('');
	}

	function kurumSatirOzet(kurum, ozet) {
		var kurumId = kurum.id || kurum.kurum_id || '';
		var ad = kurum.name || kurum.kurum_adi || '—';
		var adKey = String(ad).trim().toLocaleLowerCase('tr-TR');
		var k = (kurumId && ozet.byId[kurumId]) || ozet.byAd[adKey] || {};
		var urunler = Array.isArray(k.ilgilenilen_urunler) && k.ilgilenilen_urunler.length
			? k.ilgilenilen_urunler.join(', ')
			: (k.urun_adi || '—');
		var eklenme = kurum.created_at || kurum.eklenme_tarihi || k.tarih;
		return { kurumId: kurumId, ad: ad, k: k, urunler: urunler, eklenme: eklenme };
	}

	function renderKurumKartlar(kurumlar, analizOzet) {
		if (!kurumKartlar)
			return;
		if (Array.isArray(kurumlar))
			kurumListeCache = kurumlar.slice();
		if (analizOzet)
			kurumOzetCache = analizOzet;
		var Q = window.CrmQuery;
		var st = tabloSorgu.kurum;
		var ozet = kurumOzetCache || { byId: {}, byAd: {} };
		var isAdmin = window.Auth && window.Auth.isAdmin && window.Auth.isAdmin();
		var ham = kurumListeCache.slice();
		var liste = ham.map(function (kurum) {
			return { kurum: kurum, o: kurumSatirOzet(kurum, ozet) };
		}).filter(function (row) {
			if (!kurumSatirFiltreUygun(row, st))
				return false;
			return !Q || Q.match(st.q, [row.o.ad, tarihYaz(row.o.eklenme), row.o.k.durum, row.o.urunler, row.o.eklenme]);
		});
		if (Q) {
			liste.sort(function (a, b) {
				var av, bv;
				if (st.sort === 'tarih') { av = a.o.eklenme || ''; bv = b.o.eklenme || ''; }
				else if (st.sort === 'urun') { av = a.o.urunler; bv = b.o.urunler; }
				else if (st.sort === 'durum') { av = a.o.k.durum; bv = b.o.k.durum; }
				else if (st.sort === 'surec') { av = a.o.k.surec_tipi || a.o.k.abonelik_tipi; bv = b.o.k.surec_tipi || b.o.k.abonelik_tipi; }
				else { av = a.o.ad; bv = b.o.ad; }
				return Q.cmp(av, bv, st.dir);
			});
			Q.paintSort(document.getElementById('kurum-tablosu'), st);
			Q.paintColFilter(document.getElementById('kurum-tablosu'), st, ['durum', 'surec', 'urun']);
		}
		var kurumDurumSel = document.getElementById('kurum-filtre-durum');
		if (kurumDurumSel && kurumDurumSel.value !== (st.durum || ''))
			kurumDurumSel.value = st.durum || '';
		yazSonuc('kurum-sonuc', liste.length, ham.length);
		if (!liste.length) {
			kurumKartlar.innerHTML = '<tr><td colspan="6">' +
				(st.q || st.durum || st.surec || st.urun ? 'Filtreyle eşleşen kurum yok.' : 'Henüz kurum kaydı yok.') +
			'</td></tr>';
			return;
		}
		kurumKartlar.innerHTML = liste.map(function (row) {
			var kurumId = row.o.kurumId;
			var ad = row.o.ad;
			var k = row.o.k;
			var adminAksiyon = isAdmin && kurumId
				? '<td class="crm-admin-only crm-data-actions">' +
					'<span class="crm-action-pills">' +
					'<button type="button" data-kurum-edit="' + kacis(String(kurumId)) + '" data-kurum-ad="' + kacis(ad) + '">Düzenle</button>' +
					'<button type="button" class="is-danger" data-kurum-del="' + kacis(String(kurumId)) + '" data-kurum-ad="' + kacis(ad) + '">Sil</button>' +
					'</span>' +
				'</td>'
				: '<td class="crm-admin-only"></td>';
			return '<tr class="crm-data-row" data-id="' + kacis(String(k.id || k.analysis_id || kurumId || '')) + '" data-kurum-id="' + kacis(String(kurumId)) + '" data-kurum="' + kacis(ad) + '" tabindex="0">' +
				'<td><strong>' + kacis(ad) + '</strong></td>' +
				'<td>' + kacis(tarihYaz(row.o.eklenme)) + '</td>' +
				'<td>' + kacis(row.o.urunler) + '</td>' +
				'<td class="crm-pill-cell"><span class="crm-badge ' + durumSinif(k.durum) + '">' + kacis(k.durum || '—') + '</span></td>' +
				'<td class="crm-pill-cell"><span class="crm-chip crm-chip-subscription ' + surecTipiSinif(k.surec_tipi || k.abonelik_tipi) + '">' +
					kacis(surecTipiSec(k.surec_tipi || k.abonelik_tipi)) +
				'</span></td>' +
				adminAksiyon +
			'</tr>';
		}).join('');
	}

	function yukleKurumKartlari(analizKayitlari) {
		if (!kurumKartlar)
			return Promise.resolve();
		var ozet = analizOzetHaritasi(analizKayitlari || sonKayitlar);
		return apiGet('/kurumlar')
			.then(function (data) {
				var liste = (data && data.kurum_listesi) || [];
				if (!liste.length) {
					var mesaj = (data && data.mesaj) ? String(data.mesaj) : 'Henüz kurum kaydı yok.';
					kurumKartlar.innerHTML = '<tr><td colspan="6">' + kacis(mesaj) + '</td></tr>';
					return;
				}
				renderKurumKartlar(liste, ozet);
			})
			.catch(function () {
				kurumKartlar.innerHTML = '<tr><td colspan="6">Kurumlar yüklenemedi.</td></tr>';
			});
	}

	function kurumModalKapat() {
		if (kurumModalEl) kurumModalEl.hidden = true;
	}

	function kurumModalAc(mode, kurumId, ad) {
		kurumModalMode = mode || 'add';
		kurumModalId = kurumId || null;
		var title = document.getElementById('kurum-modal-title');
		var form = document.getElementById('kurum-form');
		var delPanel = document.getElementById('kurum-sil-panel');
		var input = document.getElementById('kurum-ad-input');
		var hata = document.getElementById('kurum-form-hata');
		var silHata = document.getElementById('kurum-sil-hata');
		var silMetin = document.getElementById('kurum-sil-metin');
		var kaydetBtn = document.getElementById('kurum-form-kaydet');
		if (hata) hata.hidden = true;
		if (silHata) silHata.hidden = true;
		if (kurumModalMode === 'delete') {
			if (title) title.textContent = 'Kurumu Sil';
			if (form) form.hidden = true;
			if (delPanel) delPanel.hidden = false;
			if (silMetin)
				silMetin.textContent = '"' + (ad || 'Kurum') + '" silinsin mi?';
		} else {
			if (form) form.hidden = false;
			if (delPanel) delPanel.hidden = true;
			if (title) title.textContent = kurumModalMode === 'edit' ? 'Kurumu Düzenle' : 'Yeni Kurum';
			if (input) {
				input.value = kurumModalMode === 'edit' ? (ad || '') : '';
				input.disabled = false;
			}
			if (kaydetBtn) kaydetBtn.textContent = kurumModalMode === 'edit' ? 'Güncelle' : 'Ekle';
		}
		if (kurumModalEl) kurumModalEl.hidden = false;
		if (kurumModalMode !== 'delete' && input) input.focus();
	}

	function kurumEkleDialog() {
		kurumModalAc('add');
	}

	function kurumDuzenleDialog(kurumId, mevcutAd) {
		kurumModalAc('edit', kurumId, mevcutAd);
	}

	function kurumSilOnay(kurumId, ad) {
		kurumModalAc('delete', kurumId, ad);
	}

	function kurumKaydetSubmit(event) {
		if (event) event.preventDefault();
		var input = document.getElementById('kurum-ad-input');
		var hata = document.getElementById('kurum-form-hata');
		var kaydetBtn = document.getElementById('kurum-form-kaydet');
		var ad = input ? String(input.value || '').trim() : '';
		if (!ad) {
			if (hata) { hata.textContent = 'Kurum adı zorunludur.'; hata.hidden = false; }
			return;
		}
		if (kaydetBtn) kaydetBtn.disabled = true;
		var istek;
		if (kurumModalMode === 'edit' && kurumModalId) {
			istek = apiPut('/kurum/' + encodeURIComponent(kurumModalId), { yeni_ad: ad });
		} else {
			istek = apiPost('/kurumlar/', { name: ad, type: 'UNIVERSITE' });
		}
		istek.then(function () {
			kurumModalKapat();
			if (typeof window.gosterToast === 'function')
				window.gosterToast(kurumModalMode === 'edit' ? 'Kurum güncellendi' : 'Kurum eklendi', 'ok');
			yukleKayitTablosu();
			if (typeof window.loadGlobalStats === 'function')
				window.loadGlobalStats();
		}).catch(function (err) {
			if (hata) {
				hata.textContent = (err && err.message) || 'İşlem başarısız';
				hata.hidden = false;
			}
		}).finally(function () {
			if (kaydetBtn) kaydetBtn.disabled = false;
		});
	}

	function kurumSilUygula() {
		if (!kurumModalId) return;
		var silBtn = document.getElementById('kurum-sil-evet');
		var silHata = document.getElementById('kurum-sil-hata');
		if (silHata) silHata.hidden = true;
		if (silBtn) silBtn.disabled = true;
		apiDelete('/kurum/' + encodeURIComponent(kurumModalId))
			.then(function () {
				kurumModalKapat();
				if (typeof window.gosterToast === 'function')
					window.gosterToast('Kurum silindi', 'ok');
				yukleKayitTablosu();
				if (typeof window.loadGlobalStats === 'function')
					window.loadGlobalStats();
			})
			.catch(function (err) {
				if (silHata) {
					silHata.textContent = (err && err.message) || 'Kurum silinemedi';
					silHata.hidden = false;
				}
			})
			.finally(function () {
				if (silBtn) silBtn.disabled = false;
			});
	}

	function drawerAcGoster() {
		if (!drawer)
			return;
		drawer.hidden = false;
		window.setTimeout(function () {
			drawer.classList.add('is-open');
		}, 16);
	}

	function drawerKapat() {
		if (!drawer)
			return;
		drawer.classList.remove('is-open');
		window.setTimeout(function () {
			if (!drawer.classList.contains('is-open'))
				drawer.hidden = true;
		}, 320);
		drawerKayitId = null;
	}

	function drawerKapatHemen() {
		if (!drawer)
			return;
		drawer.classList.remove('is-open');
		drawer.hidden = true;
		drawerKayitId = null;
	}

	function drawerDoldur(kayit) {
		if (!kayit)
			return;
		drawerKayitId = kayit.id || null;
		if (drawerYukle) drawerYukle.hidden = true;
		if (drawerHata) drawerHata.hidden = true;
		if (drawerIcerik) drawerIcerik.hidden = false;
		if (drawerKurum) drawerKurum.textContent = kayit.kurum_adi || 'Görüşme detayı';
		if (drawerTarih) drawerTarih.textContent = tarihYaz(kayit.tarih || kayit.son_gorusme_tarihi);
		if (drawerDurum) {
			drawerDurum.className = 'crm-badge ' + durumSinif(kayit.durum || kayit.gorusme_durumu);
			drawerDurum.textContent = kayit.durum || kayit.gorusme_durumu || '—';
		}
		if (drawerSurec) {
			var surec = surecTipiSec(kayit.surec_tipi || kayit.abonelik_tipi);
			drawerSurec.className = 'crm-chip crm-chip-subscription ' + surecTipiSinif(surec);
			drawerSurec.textContent = surec;
		}
		if (drawerUrunler) {
			drawerUrunler.innerHTML = '';
			var urunler = Array.isArray(kayit.ilgilenilen_urunler) ? kayit.ilgilenilen_urunler : [];
			if (!urunler.length && (kayit.urun_adi || kayit.urun_kodu))
				urunler = [kayit.urun_adi || kayit.urun_kodu];
			urunler.forEach(function (ad) {
				if (!ad) return;
				var chip = document.createElement('span');
				chip.className = 'crm-chip crm-chip-product';
				chip.textContent = ad;
				drawerUrunler.appendChild(chip);
			});
		}
		if (drawerNot)
			drawerNot.textContent = kayit.not_icerigi || kayit.gecmis_not || 'Kayıtlı transkript yok.';
		var adminDrawer = window.Auth && window.Auth.isAdmin && window.Auth.isAdmin();
		var curUser = window.Auth && window.Auth.getUser && window.Auth.getUser();
		var userOwns = curUser && kayit.user_id && String(curUser.id) === String(kayit.user_id);
		var canManage = adminDrawer || userOwns;
		if (drawerDuzenle)
			drawerDuzenle.hidden = !drawerKayitId || !canManage;
		if (drawerSil)
			drawerSil.hidden = !drawerKayitId || !canManage;
	}

	function detayCekmecesiniAc(id) {
		drawerKayitId = id;
		if (drawer) drawer.setAttribute('data-id', String(id));
		var yerel = kayitCache[String(id)];
		if (drawerIcerik) drawerIcerik.hidden = !yerel;
		if (drawerHata) drawerHata.hidden = true;
		if (drawerYukle) drawerYukle.hidden = !yerel;
		if (yerel)
			drawerDoldur(yerel);
		else if (drawerKurum)
			drawerKurum.textContent = 'Görüşme detayı';
		drawerAcGoster();
		return apiGet('/api/analizler/' + id)
			.then(function (kayit) {
				if (kayit) {
					kayitCache[String(kayit.id)] = kayit;
					drawerDoldur(kayit);
				}
			})
			.catch(function (err) {
				if (drawerYukle) drawerYukle.hidden = true;
				if (!yerel) {
					if (drawerIcerik) drawerIcerik.hidden = true;
					if (drawerHata) drawerHata.hidden = false;
					if (drawerHataMetni) drawerHataMetni.textContent = err.message || 'Kayıt açılamadı';
				}
			});
	}

	function kurumCekmecesiniAc(item) {
		var kurum = item && typeof item === 'object'
			? {
				id: item.kurum_id || item.institution_id || null,
				name: item.name || item.kurum_adi || ''
			}
			: { id: null, name: String(item || '') };
		if (drawerKurum) drawerKurum.textContent = kurum.name || 'Kurum detayı';
		if (drawerIcerik) drawerIcerik.hidden = true;
		if (drawerHata) drawerHata.hidden = true;
		if (drawerYukle) drawerYukle.hidden = false;
		drawerAcGoster();
		if (!kurum.id && !kurum.name) {
			if (drawerYukle) drawerYukle.hidden = true;
			if (drawerHata) drawerHata.hidden = false;
			if (drawerHataMetni) drawerHataMetni.textContent = 'Kurum detayı alınamadı.';
			return;
		}
		var query = kurum.id
			? ('id=' + encodeURIComponent(kurum.id))
			: ('ad=' + encodeURIComponent(kurum.name));
		return apiGet('/api/kurum-detay?' + query)
			.then(function (data) {
				drawerDoldur({
					id: data.son_analiz_id || null,
					kurum_adi: data.kurum_adi,
					tarih: data.son_gorusme_tarihi,
					durum: data.gorusme_durumu,
					surec_tipi: data.surec_tipi,
					ilgilenilen_urunler: data.ilgilenilen_urunler,
					not_icerigi: data.gecmis_not,
					gorevler: data.gorevler || []
				});
			})
			.catch(function () {
				if (drawerYukle) drawerYukle.hidden = true;
				if (drawerIcerik) drawerIcerik.hidden = true;
				if (drawerHata) drawerHata.hidden = false;
				if (drawerHataMetni) drawerHataMetni.textContent = 'Kurum detayı alınamadı.';
			});
	}

	function crmOnayDialog(ayarlar) {
		var modal = document.getElementById('crm-onay-modal');
		var baslikEl = document.getElementById('crm-onay-baslik');
		var mesajEl = document.getElementById('crm-onay-mesaj');
		var evetBtn = document.getElementById('crm-onay-evet');
		var iptalBtn = document.getElementById('crm-onay-iptal');
		if (!modal) {
			if (window.confirm((ayarlar && ayarlar.mesaj) || 'Emin misiniz?')) {
				if (ayarlar && typeof ayarlar.onay === 'function') ayarlar.onay();
			}
			return;
		}
		if (baslikEl && ayarlar.baslik) baslikEl.textContent = ayarlar.baslik;
		if (mesajEl && ayarlar.mesaj) mesajEl.textContent = ayarlar.mesaj;
		if (evetBtn && ayarlar.buton) evetBtn.textContent = ayarlar.buton;

		modal.hidden = false;

		function temizle() {
			modal.hidden = true;
			if (evetBtn) evetBtn.removeEventListener('click', onEvet);
			if (iptalBtn) iptalBtn.removeEventListener('click', onIptal);
			modal.removeEventListener('click', onBackdrop);
		}

		function onEvet(e) {
			if (e) { e.preventDefault(); e.stopPropagation(); }
			temizle();
			if (ayarlar && typeof ayarlar.onay === 'function') ayarlar.onay();
		}

		function onIptal(e) {
			if (e) { e.preventDefault(); e.stopPropagation(); }
			temizle();
			if (ayarlar && typeof ayarlar.iptal === 'function') ayarlar.iptal();
		}

		function onBackdrop(e) {
			if (e.target && e.target.hasAttribute('data-close-onay-modal')) {
				if (e) { e.preventDefault(); e.stopPropagation(); }
				temizle();
			}
		}

		if (evetBtn) evetBtn.addEventListener('click', onEvet);
		if (iptalBtn) iptalBtn.addEventListener('click', onIptal);
		modal.addEventListener('click', onBackdrop);
	}

	function kayitSilOnayla(id) {
		if (!id) {
			if (typeof window.gosterToast === 'function')
				window.gosterToast('Silinecek görüşme kaydı bulunamadı.', 'hata');
			return;
		}
		crmOnayDialog({
			baslik: 'Görüşmeyi Sil',
			mesaj: 'Bu görüşme kaydını silmek istediğinize emin misiniz? Kayda ait görevler de kaldırılacaktır.',
			buton: 'Evet, Sil',
			onay: function () {
				apiDelete('/api/analizler/' + id)
					.then(function () {
						if (typeof drawerKapatHemen === 'function')
							drawerKapatHemen();
						var dr = document.getElementById('kayit-drawer');
						if (dr) {
							dr.classList.remove('is-open');
							dr.hidden = true;
						}
						delete kayitCache[String(id)];
						sonKayitlar = (sonKayitlar || []).filter(function (k) { return String(k.id) !== String(id); });
						renderDashKartlar(sonKayitlar);
						renderNotlarKartlar(sonKayitlar);
						renderGorusmeKartlar(sonKayitlar);
						yukleKayitTablosu();
						if (typeof window.loadGlobalStats === 'function')
							window.loadGlobalStats();
						if (typeof window.gosterToast === 'function')
							window.gosterToast('Görüşme kaydı silindi.', 'ok');
					})
					.catch(function (err) {
						if (typeof window.gosterToast === 'function')
							window.gosterToast((err && err.message) || 'Silme işlemi başarısız', 'hata');
						else
							alert((err && err.message) || 'Silme işlemi başarısız');
					});
			}
		});
	}

	function kayitSilTiklama(e) {
		var silBtn = e.target.closest ? e.target.closest('[data-action="sil-kart"]') : null;
		if (silBtn) {
			e.preventDefault();
			e.stopPropagation();
			var id = silBtn.getAttribute('data-id');
			kayitSilOnayla(id);
			return true;
		}
		return false;
	}

	if (dashKartlar) {
		dashKartlar.addEventListener('click', function (e) {
			if (kayitSilTiklama(e)) return;
			var kart = e.target.closest ? e.target.closest('.crm-mini-card[data-id]') : null;
			if (kart)
				detayCekmecesiniAc(kart.getAttribute('data-id'));
		});
	}

	if (notlarKartlar) {
		notlarKartlar.addEventListener('click', function (e) {
			if (kayitSilTiklama(e)) return;
			var kart = e.target.closest ? e.target.closest('.crm-mini-card[data-id]') : null;
			if (kart)
				detayCekmecesiniAc(kart.getAttribute('data-id'));
		});
	}

	var btnNavNotEkle = document.getElementById('btn-nav-not-ekle');
	if (btnNavNotEkle)
		btnNavNotEkle.addEventListener('click', notEklePanelineGit);
	var btnNotlarimEkle = document.getElementById('btn-notlarim-ekle');
	if (btnNotlarimEkle)
		btnNotlarimEkle.addEventListener('click', notEklePanelineGit);

	document.addEventListener('crm-view-change', function (e) {
		var view = e && e.detail && e.detail.view;
		if (view !== 'notlarim')
			notEkleBlokunuTasi('dash-not-ekle-yuvasi');
	});

	if (kurumKartlar) {
		kurumKartlar.addEventListener('click', function (e) {
			var editBtn = e.target.closest ? e.target.closest('[data-kurum-edit]') : null;
			if (editBtn) {
				e.preventDefault();
				e.stopPropagation();
				kurumDuzenleDialog(editBtn.getAttribute('data-kurum-edit'), editBtn.getAttribute('data-kurum-ad'));
				return;
			}
			var delBtn = e.target.closest ? e.target.closest('[data-kurum-del]') : null;
			if (delBtn) {
				e.preventDefault();
				e.stopPropagation();
				kurumSilOnay(delBtn.getAttribute('data-kurum-del'), delBtn.getAttribute('data-kurum-ad'));
				return;
			}
			var satir = e.target.closest ? e.target.closest('tr[data-kurum-id]') : null;
			if (!satir)
				return;
			kurumCekmecesiniAc({
				kurum_id: satir.getAttribute('data-kurum-id'),
				name: satir.getAttribute('data-kurum')
			});
		});
	}

	if (gorusmeKartlar) {
		gorusmeKartlar.addEventListener('click', function (e) {
			if (kayitSilTiklama(e)) return;
			var kart = e.target.closest ? e.target.closest('.crm-mini-card[data-id]') : null;
			if (kart)
				detayCekmecesiniAc(kart.getAttribute('data-id'));
		});
	}

	if (urunTbody) {
		urunTbody.addEventListener('click', function (e) {
			var silBtn = e.target.closest ? e.target.closest('.crm-sil-btn') : null;
			if (silBtn) {
				e.preventDefault();
				e.stopPropagation();
				var silId = silBtn.getAttribute('data-id');
				var silAd = silBtn.getAttribute('data-ad') || 'bu ürünü';
				if (!silId || !confirm('"' + silAd + '" ürününü kaldırmak istiyor musunuz?'))
					return;
				apiDelete('/api/urunler/' + encodeURIComponent(silId))
					.then(function () {
						if (acikUrunId === silId)
							acikUrunId = null;
						if (typeof gosterToast === 'function')
							gosterToast('Ürün kaldırıldı.', 'ok');
						return urunleriYukle();
					})
					.catch(function (err) {
						if (typeof gosterToast === 'function')
							gosterToast((err && err.message) || 'Ürün kaldırılamadı.', 'hata');
					});
				return;
			}
			var kurumBtn = e.target.closest ? e.target.closest('.crm-data-kurum-link') : null;
			if (kurumBtn) {
				e.preventDefault();
				kurumCekmecesiniAc({
					kurum_id: kurumBtn.getAttribute('data-kurum-id'),
					name: kurumBtn.getAttribute('data-kurum')
				});
				return;
			}
			var satir = e.target.closest ? e.target.closest('tr[data-urun-id]') : null;
			if (!satir)
				return;
			var uid = satir.getAttribute('data-urun-id');
			acikUrunId = acikUrunId === uid ? null : uid;
			renderUrunTablosu();
		});
	}

	(function tabloAramaSiralaBagla() {
		var Q = window.CrmQuery;
		var timers = {};
		function gecikmeli(ad, fn) {
			clearTimeout(timers[ad]);
			timers[ad] = setTimeout(fn, 80);
		}
		function baglaArama(id, fn) {
			var el = document.getElementById(id);
			if (!el) return;
			el.addEventListener('input', function () { gecikmeli(id, fn); });
		}
		function baglaFiltre(id, fn) {
			var el = document.getElementById(id);
			if (!el) return;
			el.addEventListener('change', fn);
		}
		function baglaTabloBaslik(tabloId, state, yenile, opts) {
			var tablo = document.getElementById(tabloId);
			if (!tablo || !Q) return;
			opts = opts || {};
			tablo.addEventListener('click', function (e) {
				var btn = e.target.closest ? e.target.closest('.crm-sort-btn') : null;
				if (!btn || !tablo.contains(btn)) return;
				e.preventDefault();
				var sortKey = btn.getAttribute('data-sort');
				var filterKey = btn.getAttribute('data-col-filter');
				if (filterKey && !(e.target.closest && e.target.closest('.crm-sort-icon'))) {
					var degerFn = opts.degerler && opts.degerler[filterKey];
					if (degerFn) {
						var degerler = degerFn();
						var baslik = (opts.etiketler && opts.etiketler[filterKey]) || filterKey;
						var secili = (state.filtre && state.filtre[filterKey]) || state[filterKey] || '';
						kolonFiltreMenuAc(btn, baslik, degerler, secili, function (val) {
							if (state.filtre)
								state.filtre[filterKey] = val;
							else
								state[filterKey] = val;
							if (opts.toolbarSync)
								opts.toolbarSync(filterKey, val);
							yenile();
						});
					}
					return;
				}
				kolonFiltrePopoverKapat();
				Q.toggleSort(state, sortKey);
				yenile();
			});
		}
		baglaArama('gorusme-arama', function () {
			tabloSorgu.gorusme.q = (document.getElementById('gorusme-arama') || {}).value || '';
			renderGorusmeKartlar();
		});
		baglaFiltre('gorusme-filtre-durum', function () {
			tabloSorgu.gorusme.durum = (document.getElementById('gorusme-filtre-durum') || {}).value || '';
			renderGorusmeKartlar();
		});
		baglaFiltre('gorusme-filtre-surec', function () {
			tabloSorgu.gorusme.surec = (document.getElementById('gorusme-filtre-surec') || {}).value || '';
			renderGorusmeKartlar();
		});
		baglaFiltre('gorusme-filtre-urun', function () {
			tabloSorgu.gorusme.urun = (document.getElementById('gorusme-filtre-urun') || {}).value || '';
			renderGorusmeKartlar();
		});
		baglaFiltre('gorusme-siralama', function () {
			gorusmeSiralamaUygula((document.getElementById('gorusme-siralama') || {}).value);
			renderGorusmeKartlar();
		});

		baglaArama('kurum-arama', function () {
			tabloSorgu.kurum.q = (document.getElementById('kurum-arama') || {}).value || '';
			renderKurumKartlar();
		});
		baglaFiltre('kurum-filtre-durum', function () {
			tabloSorgu.kurum.durum = (document.getElementById('kurum-filtre-durum') || {}).value || '';
			renderKurumKartlar();
		});
		baglaTabloBaslik('kurum-tablosu', tabloSorgu.kurum, function () { renderKurumKartlar(); }, {
			etiketler: { durum: 'Durum', surec: 'Süreç', urun: 'Ürün' },
			degerler: {
				durum: kurumKolonDegerleri.bind(null, 'durum'),
				surec: kurumKolonDegerleri.bind(null, 'surec'),
				urun: kurumKolonDegerleri.bind(null, 'urun')
			},
			toolbarSync: function (key, val) {
				if (key === 'durum') {
					var el = document.getElementById('kurum-filtre-durum');
					if (el) el.value = val || '';
				}
			}
		});

		baglaArama('urun-arama', function () {
			tabloSorgu.urun.q = (document.getElementById('urun-arama') || {}).value || '';
			renderUrunTablosu();
		});
		baglaTabloBaslik('urun-tablosu', tabloSorgu.urun, renderUrunTablosu, {
			etiketler: { company: 'Şirket' },
			degerler: { company: urunSirketDegerleri }
		});

		baglaArama('notlar-arama', function () {
			tabloSorgu.not.q = (document.getElementById('notlar-arama') || {}).value || '';
			renderNotlarKartlar();
		});

		baglaArama('db-arama', function () {
			tabloSorgu.db.q = (document.getElementById('db-arama') || {}).value || '';
			renderDbGorunum();
		});

		document.addEventListener('click', function (e) {
			if (!kolonFiltrePopover || kolonFiltrePopover.hidden)
				return;
			if (e.target.closest && (e.target.closest('#crm-col-filter-popover') || e.target.closest('[data-col-filter]')))
				return;
			kolonFiltrePopoverKapat();
		});
		document.addEventListener('keydown', function (e) {
			if (e.key === 'Escape')
				kolonFiltrePopoverKapat();
		});
	})();

	(function dbTabloSiralamaBagla() {
		var dbTablo = document.getElementById('veritabani-tablosu');
		var Q = window.CrmQuery;
		if (!dbTablo || !Q)
			return;
		dbTablo.addEventListener('click', function (e) {
			var btn = e.target.closest ? e.target.closest('.crm-sort-btn') : null;
			if (!btn || !dbTablo.contains(btn))
				return;
			e.preventDefault();
			var sortKey = btn.getAttribute('data-sort');
			var filterKey = btn.getAttribute('data-col-filter');
			if (filterKey && !(e.target.closest && e.target.closest('.crm-sort-icon'))) {
				var degerler = dbKolonDegerleri(filterKey);
				var secili = (tabloSorgu.db.filtre && tabloSorgu.db.filtre[filterKey]) || '';
				kolonFiltreMenuAc(btn, filterKey, degerler, secili, function (val) {
					if (!tabloSorgu.db.filtre)
						tabloSorgu.db.filtre = {};
					if (val)
						tabloSorgu.db.filtre[filterKey] = val;
					else
						delete tabloSorgu.db.filtre[filterKey];
					renderDbGorunum();
				});
				return;
			}
			kolonFiltrePopoverKapat();
			Q.toggleSort(tabloSorgu.db, sortKey);
			renderDbGorunum();
		});
	})();

	var btnKurumEkle = document.getElementById('btn-kurum-ekle');
	if (btnKurumEkle)
		btnKurumEkle.addEventListener('click', kurumEkleDialog);

	var kurumModalEl = document.getElementById('kurum-modal');
	var kurumModalMode = 'add';
	var kurumModalId = null;
	var kurumForm = document.getElementById('kurum-form');
	var kurumModalKapatBtn = document.getElementById('kurum-modal-kapat');
	var kurumFormIptal = document.getElementById('kurum-form-iptal');
	var kurumSilHayir = document.getElementById('kurum-sil-hayir');
	var kurumSilEvet = document.getElementById('kurum-sil-evet');
	if (kurumForm)
		kurumForm.addEventListener('submit', kurumKaydetSubmit);
	if (kurumModalKapatBtn) kurumModalKapatBtn.addEventListener('click', kurumModalKapat);
	if (kurumFormIptal) kurumFormIptal.addEventListener('click', kurumModalKapat);
	if (kurumSilHayir) kurumSilHayir.addEventListener('click', kurumModalKapat);
	if (kurumSilEvet) kurumSilEvet.addEventListener('click', kurumSilUygula);
	if (kurumModalEl) {
		kurumModalEl.addEventListener('click', function (e) {
			if (e.target && e.target.getAttribute('data-close-kurum-modal') !== null)
				kurumModalKapat();
		});
	}

	if (veritabaniTbody) {
		veritabaniTbody.addEventListener('click', function (e) {
			var btn = e.target.closest ? e.target.closest('.crm-db-edit-btn') : null;
			if (!btn)
				return;
			var index = parseInt(btn.getAttribute('data-row-index'), 10);
			if (isNaN(index) || !seciliTabloKayitlar[index])
				return;
			dbEditModalAc(seciliTabloKayitlar[index]);
		});
	}

	if (dbEditForm)
		dbEditForm.addEventListener('submit', dbEditKaydet);
	var dbEditKapat = document.getElementById('db-edit-kapat');
	var dbEditIptal = document.getElementById('db-edit-iptal');
	if (dbEditKapat) dbEditKapat.addEventListener('click', dbEditModalKapat);
	if (dbEditIptal) dbEditIptal.addEventListener('click', dbEditModalKapat);
	if (dbEditModal) {
		dbEditModal.addEventListener('click', function (e) {
			if (e.target && e.target.getAttribute('data-close-db-edit') !== null)
				dbEditModalKapat();
		});
	}

	function gorevBasligiAl(g) {
		if (!g) return '';
		if (typeof g === 'string') return g.trim();
		return String(g.baslik || g.task || g.title || '').trim();
	}

	function renderKayitGorevleri(gorevler, kurumAdi) {
		if (!gorevlerWrap || !gorevlerList)
			return;
		// Yalnızca AI'nın bu görüşmeden çıkardığı To-Do notları
		var gecerli = (Array.isArray(gorevler) ? gorevler : []).filter(function (g) {
			if (!gorevBasligiAl(g))
				return false;
			var kaynak = String((g && (g.kaynak || g.source)) || 'ai').toLowerCase();
			return kaynak !== 'manuel' && kaynak !== 'manual';
		});
		gorevlerWrap.hidden = false;
		gorevlerList.innerHTML = '';
		if (!gecerli.length) {
			if (gorevlerBos) gorevlerBos.hidden = false;
			return;
		}
		if (gorevlerBos) gorevlerBos.hidden = true;
		var varsayilanKurum = String(kurumAdi || '').trim();
		gecerli.forEach(function (g) {
			var li = document.createElement('li');
			var check = document.createElement('button');
			var body = document.createElement('div');
			var kurumEl = document.createElement('span');
			var title = document.createElement('span');
			var atanan = document.createElement('span');
			var done = !!(g && g.tamamlandi);
			var atananAd = String((g && (g.assigned_user_name || g.gorusme_sahibi_adi)) || '').trim();
			var isAdmin = !!(window.Auth && window.Auth.isAdmin && window.Auth.isAdmin());
			var kurumAd = String((g && g.kurum_adi) || varsayilanKurum || '').trim();
			li.className = 'crm-gorev-item' + (done ? ' is-done' : '');
			if (g && g.id) {
				li.dataset.id = String(g.id);
				li.dataset.dbId = String(g.id);
			}
			if (g && g.company_id)
				li.dataset.companyId = String(g.company_id);
			if (g && (g.assigned_user_id || g.user_id))
				li.dataset.assignedUserId = String(g.assigned_user_id || g.user_id);
			check.type = 'button';
			check.className = 'crm-gorev-check' + (done ? ' is-on' : '');
			check.setAttribute('aria-pressed', done ? 'true' : 'false');
			check.setAttribute('aria-label', done ? 'Görevi geri al' : 'Görevi tamamlandı işaretle');
			check.innerHTML = '<span class="icon solid fa-check" aria-hidden="true"></span>';
			body.className = 'crm-gorev-body';
			kurumEl.className = 'crm-gorev-kurum';
			kurumEl.textContent = kurumAd || 'Kurum belirtilmedi';
			title.className = 'crm-gorev-title';
			title.textContent = gorevBasligiAl(g);
			atanan.className = 'crm-gorev-atanan';
			atanan.setAttribute('data-atanan-etiket', '');
			atanan.textContent = atananAd || (isAdmin ? 'Atanmamış' : '');
			body.appendChild(kurumEl);
			body.appendChild(title);
			if (atanan.textContent)
				body.appendChild(atanan);
			li.appendChild(check);
			li.appendChild(body);
			if (isAdmin && g && g.id) {
				var ataWrap = document.createElement('div');
				var ataBtn = document.createElement('button');
				var ataMenu = document.createElement('div');
				ataWrap.className = 'crm-todo-ata-wrap';
				ataBtn.type = 'button';
				ataBtn.className = 'crm-todo-ata-btn';
				ataBtn.textContent = 'Görev Ata';
				ataMenu.className = 'crm-todo-ata-menu';
				ataMenu.hidden = true;
				ataMenu.innerHTML =
					'<label>Personel seçin</label>' +
					'<select class="crm-todo-ata-select"><option value="">Listeleniyor...</option></select>' +
					'<button type="button" class="crm-todo-ata-onay">Onayla</button>';
				ataWrap.appendChild(ataBtn);
				ataWrap.appendChild(ataMenu);
				li.appendChild(ataWrap);
			}
			gorevlerList.appendChild(li);
		});
	}

	function gorevTamamlandiGuncelle(gorevId, tamamlandi, li) {
		fetch(API_BASE + '/api/gorevler/' + gorevId, {
			method: 'PATCH',
			headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
			body: JSON.stringify({ tamamlandi: tamamlandi })
		})
			.then(function (r) { return r.text().then(function (raw) { return jsonAl(r, raw); }); })
			.catch(function () {
				// Sunucu güncellemesi başarısız olursa arayüzü eski haline döndür,
				// böylece kullanıcı tamamlanmış görünen ama kaydedilmemiş bir
				// görev görmez.
				if (li) {
					li.classList.toggle('is-done', !tamamlandi);
					var check = li.querySelector('.crm-gorev-check');
					if (check) check.classList.toggle('is-on', !tamamlandi);
				}
			});
	}

	if (gorevlerList) {
		gorevlerList.addEventListener('click', function (e) {
			var ataBtn = e.target && e.target.closest ? e.target.closest('.crm-todo-ata-btn') : null;
			var ataOnay = e.target && e.target.closest ? e.target.closest('.crm-todo-ata-onay') : null;
			var check = e.target && e.target.closest ? e.target.closest('.crm-gorev-check') : null;
			var li = e.target && e.target.closest ? e.target.closest('.crm-gorev-item') : null;
			if (e.target.closest && e.target.closest('.crm-todo-ata-menu') && !ataOnay)
				return;
			if (ataBtn && li) {
				e.preventDefault();
				e.stopPropagation();
				if (typeof window.crmAtaMenusunuAc === 'function')
					window.crmAtaMenusunuAc(li);
				return;
			}
			if (ataOnay && li) {
				e.preventDefault();
				e.stopPropagation();
				if (typeof window.crmGoreviAtaOnayla === 'function')
					window.crmGoreviAtaOnayla(li);
				return;
			}
			if (!check || !li || !li.dataset.id)
				return;
			e.preventDefault();
			var yeniDurum = !li.classList.contains('is-done');
			li.classList.toggle('is-done', yeniDurum);
			check.classList.toggle('is-on', yeniDurum);
			check.setAttribute('aria-pressed', yeniDurum ? 'true' : 'false');
			gorevTamamlandiGuncelle(li.dataset.id, yeniDurum, li);
		});
	}

	function kayitUrunOrijinalSifirla() {
		kayitUrunOrijinalAdlar = [];
		kayitUrunOrijinalKodlar = [];
		kayitUrunIlkDeger = '';
	}

	function urunleriYukle() {
		var oncekiSecim = urunEl ? kayitUrunSecimleriniAl() : { kodlar: [], adlar: [] };
		return apiGet('/api/urunler')
			.then(function (data) {
				urunlerCache = (data && data.urunler) || [];
				renderUrunTablosu();
				gorusmeUrunFiltreSelectGuncelle();
				if (!urunEl) return;
				urunEl.innerHTML = '';
				var bos = document.createElement('option');
				bos.value = '';
				bos.textContent = 'Ürün seçin';
				urunEl.appendChild(bos);
				urunlerCache.forEach(function (u) {
					var opt = document.createElement('option');
					opt.value = u.code;
					opt.textContent = u.name;
					urunEl.appendChild(opt);
				});
				if (oncekiSecim.adlar.length)
					kayitUrunSecimleriniYaz({
						urun_kodu: oncekiSecim.kodlar[0] || '',
						urun_adi: oncekiSecim.adlar[0] || '',
						ilgilenilen_urunler: oncekiSecim.adlar
					});
				else
					urunEl.value = '';
			})
			.catch(function () {});
	}

	(function urunEkleFormuBagla() {
		var form = document.getElementById('yeni-urun-form');
		var adEl = document.getElementById('yu-ad');
		var kodEl = document.getElementById('yu-kod');
		var sirketEl = document.getElementById('yu-sirket');
		var hataEl = document.getElementById('yu-hata');
		if (!form || !adEl) return;

		function urunSirketleriYukle() {
			if (!sirketEl) return Promise.resolve();
			return apiGet('/api/companies')
				.then(function (data) {
					var sirketler = (data && data.sirketler) || [];
					var onceki = sirketEl.value;
					sirketEl.innerHTML = '<option value="">Şirket seçin...</option>';
					sirketler.forEach(function (s) {
						var opt = document.createElement('option');
						opt.value = String(s.id);
						opt.textContent = s.name || ('#' + s.id);
						sirketEl.appendChild(opt);
					});
					if (onceki && Array.prototype.some.call(sirketEl.options, function (o) { return o.value === onceki; }))
						sirketEl.value = onceki;
					else if (sirketler.length === 1)
						sirketEl.value = String(sirketler[0].id);
				})
				.catch(function () {
					if (sirketEl.options.length <= 1)
						sirketEl.innerHTML = '<option value="">Şirketler yüklenemedi</option>';
				});
		}

		urunSirketleriYukle();
		form.addEventListener('submit', function (e) {
			e.preventDefault();
			if (hataEl) { hataEl.hidden = true; hataEl.textContent = ''; }
			var ad = (adEl.value || '').trim();
			var kod = (kodEl && kodEl.value || '').trim();
			var sirketId = sirketEl && sirketEl.value ? parseInt(sirketEl.value, 10) : null;
			if (!ad) {
				if (hataEl) { hataEl.hidden = false; hataEl.textContent = 'Ürün adı zorunludur.'; }
				return;
			}
			var govde = { name: ad };
			if (kod) govde.code = kod;
			if (sirketId) govde.company_id = sirketId;
			apiPost('/api/urunler', govde)
				.then(function () {
					adEl.value = '';
					if (kodEl) kodEl.value = '';
					if (typeof gosterToast === 'function')
						gosterToast('Ürün eklendi.', 'ok');
					return urunleriYukle();
				})
				.catch(function (err) {
					var mesaj = (err && err.message) || 'Ürün eklenemedi.';
					if (hataEl) { hataEl.hidden = false; hataEl.textContent = mesaj; }
					if (typeof gosterToast === 'function')
						gosterToast(mesaj, 'hata');
				});
		});
	})();

	// Süreç tipi seçeneklerini backend'deki katı Enum'dan (enums.SurecTipi)
	// dinamik olarak çeker; böylece dropdown, backend'in tek doğru kaynağı
	// ile HER ZAMAN birebir aynı kalır. Uç nokta erişilemezse HTML'deki
	// mevcut sabit <option> listesi (Hiçbiri/Deneme/Abonelik) fallback olarak
	// kalır, yani mevcut çalışan davranış hiçbir zaman bozulmaz.
	function surecTipleriYukle() {
		if (!abonelikTipiEl) return Promise.resolve();
		return apiGet('/api/surec-tipleri')
			.then(function (data) {
				var degerler = (data && data.degerler) || [];
				if (!degerler.length) return;
				var mevcutDeger = abonelikTipiEl.value;
				abonelikTipiEl.innerHTML = '';
				degerler.forEach(function (d) {
					var opt = document.createElement('option');
					opt.value = d;
					opt.textContent = d;
					abonelikTipiEl.appendChild(opt);
				});
				abonelikTipiEl.value = degerler.indexOf(mevcutDeger) >= 0 ? mevcutDeger : degerler[0];
			})
			.catch(function () {});
	}

	// Koyu/açık tema toggle: tercih localStorage'da saklanır ve <html>
	// üzerindeki 'crm-tema-acik' sınıfı ile main.css'teki `invert()` filtresi
	// tetiklenir (bkz. index.html <head> içindeki FOUC-önleyici satır içi script).
	var TEMA_ANAHTARI = 'crm-tema';
	function temaToggleBaslat() {
		var buton = document.getElementById('tema-toggle');
		if (!buton) return;
		var ikon = buton.querySelector('.tema-toggle-ikon') || buton.querySelector('.icon');
		function guncelle(acikMi) {
			document.documentElement.classList.toggle('crm-tema-acik', acikMi);
			buton.setAttribute('aria-pressed', acikMi ? 'true' : 'false');
			buton.setAttribute('aria-label', acikMi ? 'Koyu temaya geç' : 'Açık temaya geç');
			buton.title = acikMi ? 'Koyu temaya geç' : 'Açık temaya geç';
			if (ikon) {
				ikon.classList.remove('fa-cog', 'fa-sun', 'fa-moon');
				ikon.classList.add(acikMi ? 'fa-moon' : 'fa-sun');
			}
		}
		guncelle(document.documentElement.classList.contains('crm-tema-acik'));
		buton.addEventListener('click', function () {
			var yeniDurum = !document.documentElement.classList.contains('crm-tema-acik');
			guncelle(yeniDurum);
			try {
				localStorage.setItem(TEMA_ANAHTARI, yeniDurum ? 'acik' : 'koyu');
			} catch (e) {}
		});
	}

	function bildirimCaniniBaslat() {
		var kok = document.getElementById('crm-bildirim');
		var buton = document.getElementById('bildirim-toggle');
		var panel = document.getElementById('bildirim-panel');
		var badge = document.getElementById('bildirim-badge');
		var liste = document.getElementById('bildirim-liste');
		var hepsiBtn = document.getElementById('bildirim-hepsini-oku');
		if (!kok || !buton || !panel || !liste)
			return;

		var sonOkunmamis = 0;
		var ilkYukleme = true;
		var acik = false;

		function kacis(s) {
			return String(s == null ? '' : s)
				.replace(/&/g, '&amp;')
				.replace(/</g, '&lt;')
				.replace(/>/g, '&gt;')
				.replace(/"/g, '&quot;');
		}

		function zamanOnce(iso) {
			if (!iso) return '';
			var t = Date.parse(iso);
			if (!t) return '';
			var sn = Math.round((Date.now() - t) / 1000);
			if (sn < 45) return 'Az önce';
			if (sn < 3600) return Math.floor(sn / 60) + ' dk önce';
			if (sn < 86400) return Math.floor(sn / 3600) + ' sa önce';
			return Math.floor(sn / 86400) + ' gün önce';
		}

		function paneliKonumla() {
			var r = buton.getBoundingClientRect();
			var sag = Math.max(12, window.innerWidth - r.right);
			var ust = r.bottom + 8;
			panel.style.top = ust + 'px';
			panel.style.right = sag + 'px';
			panel.style.left = 'auto';
		}

		function paneliKapat() {
			acik = false;
			panel.hidden = true;
			buton.classList.remove('is-open');
			buton.setAttribute('aria-expanded', 'false');
		}

		function paneliAc() {
			acik = true;
			panel.hidden = false;
			buton.classList.add('is-open');
			buton.setAttribute('aria-expanded', 'true');
			paneliKonumla();
			yukle(true);
		}

		function rozetGuncelle(adet) {
			var n = parseInt(adet, 10) || 0;
			if (!badge) return;
			if (n <= 0) {
				badge.hidden = true;
				badge.textContent = '0';
				return;
			}
			badge.hidden = false;
			badge.textContent = n > 9 ? '9+' : String(n);
		}

		function listeCiz(bildirimler) {
			if (!bildirimler || !bildirimler.length) {
				liste.innerHTML = '<li class="bildirim-bos">Yeni bildiriminiz yok.</li>';
				return;
			}
			liste.innerHTML = bildirimler.map(function (b) {
				var okunmamis = !b.is_read;
				var govde = (b.body || '').trim();
				var kim = (b.actor_name || '').trim();
				var zaman = zamanOnce(b.created_at);
				var meta = [kim ? (kim + ' atadı') : '', zaman].filter(Boolean).join(' · ');
				return '<li><button type="button" class="bildirim-item' + (okunmamis ? ' is-unread' : '') + '" data-id="' + kacis(b.id) + '">' +
					'<span class="bildirim-item-baslik">' + kacis(b.title || 'Bildirim') + '</span>' +
					(govde ? '<span class="bildirim-item-govde">' + kacis(govde) + '</span>' : '') +
					(meta ? '<span class="bildirim-item-meta">' + kacis(meta) + '</span>' : '') +
					'</button></li>';
			}).join('');
		}

		function yukle(ciz) {
			if (typeof fetchJson !== 'function')
				return Promise.resolve();
			return fetchJson(CRM_API + '/api/bildirimler', { headers: { Accept: 'application/json' } })
				.then(function (data) {
					var adet = (data && data.okunmamis) || 0;
					if (!ilkYukleme && adet > sonOkunmamis) {
						if (typeof gosterToast === 'function')
							gosterToast('Size yeni bir görev atandı.', 'ok');
						var yeniler = ((data && data.bildirimler) || []).filter(function (b) {
							return !b.is_read;
						});
						var son = yeniler[0] || {};
						if (!(window.CrmWebFcm && CrmWebFcm.aktifMi && CrmWebFcm.aktifMi()) &&
							window.CrmOsNotify && typeof CrmOsNotify.goster === 'function')
							CrmOsNotify.goster(son.title, son.body);
					}
					sonOkunmamis = adet;
					ilkYukleme = false;
					rozetGuncelle(adet);
					if (ciz)
						listeCiz((data && data.bildirimler) || []);
				})
				.catch(function () {
					ilkYukleme = false;
				});
		}

		buton.addEventListener('click', function (e) {
			e.stopPropagation();
			if (window.CrmOsNotify && typeof CrmOsNotify.izinIste === 'function')
				CrmOsNotify.izinIste();
			if (acik) paneliKapat();
			else paneliAc();
		});

		liste.addEventListener('click', function (e) {
			var item = e.target && e.target.closest ? e.target.closest('.bildirim-item') : null;
			if (!item) return;
			var id = item.getAttribute('data-id');
			if (id && typeof fetchJson === 'function') {
				fetchJson(CRM_API + '/api/bildirimler/' + encodeURIComponent(id) + '/okundu', {
					method: 'PUT',
					headers: { Accept: 'application/json' }
				}).then(function () { yukle(true); }).catch(function () {});
			}
			paneliKapat();
			if (typeof window.crmSekmeyiAc === 'function')
				window.crmSekmeyiAc('gorevler');
		});

		if (hepsiBtn) {
			hepsiBtn.addEventListener('click', function (e) {
				e.stopPropagation();
				if (typeof fetchJson !== 'function') return;
				fetchJson(CRM_API + '/api/bildirimler/okundu-hepsi', {
					method: 'PUT',
					headers: { Accept: 'application/json' }
				}).then(function () { yukle(true); }).catch(function () {});
			});
		}

		document.addEventListener('click', function (e) {
			if (!acik) return;
			if (kok.contains(e.target) || panel.contains(e.target)) return;
			paneliKapat();
		});
		document.addEventListener('keydown', function (e) {
			if (e.key === 'Escape' && acik)
				paneliKapat();
		});
		window.addEventListener('resize', function () {
			if (acik) paneliKonumla();
		});
		window.addEventListener('scroll', function () {
			if (acik) paneliKonumla();
		}, true);

		yukle(false);
		window.setInterval(function () { yukle(acik); }, 10000);
		if (window.CrmOsNotify && typeof CrmOsNotify.izinIste === 'function')
			CrmOsNotify.izinIste();
		document.addEventListener('visibilitychange', function () {
			if (document.visibilityState === 'visible')
				yukle(acik);
		});
	}

	function yukleKayitTablosu() {
		return apiGet('/api/analizler')
			.then(function (data) {
				var kayitlar = (data && data.kayitlar) || [];
				sonKayitlar = kayitlar;
				window.crmSonNotSayisi = kayitlar.length;
				kayitCache = {};
				kayitlar.forEach(function (k) { kayitCache[String(k.id)] = k; });
				renderDashKartlar(kayitlar);
				renderNotlarKartlar(kayitlar);
				renderGorusmeKartlar(kayitlar);
				gorusmeUrunFiltreSelectGuncelle();
				return yukleKurumKartlari(kayitlar).then(function () {
					renderUrunTablosu();
					if (typeof window.crmNavRozetleriGuncelle === 'function')
						window.crmNavRozetleriGuncelle();
				});
			})
			.catch(function () {
				if (dashKartlar)
					dashKartlar.innerHTML = '<p class="crm-todo-empty">Kayıtlar yüklenemedi.</p>';
				if (notlarKartlar)
					notlarKartlar.innerHTML = '<p class="crm-todo-empty">Notlar yüklenemedi.</p>';
				if (kurumKartlar)
					kurumKartlar.innerHTML = '<tr><td colspan="6">Kayıtlar yüklenemedi.</td></tr>';
				if (gorusmeKartlar)
					gorusmeKartlar.innerHTML = '<p class="crm-todo-empty">Görüşmeler yüklenemedi.</p>';
			});
	}

	function modalAc(duzenle) {
		if (!modal) return;
		if (hataEl) {
			hataEl.hidden = true;
			hataEl.textContent = '';
		}
		if (titleEl)
			titleEl.textContent = duzenle ? 'Kaydı Düzenle' : 'Yeni Kayıt';
		if (kaydetBtn)
			kaydetBtn.textContent = duzenle ? 'Güncelle' : 'Kaydet';
		modal.hidden = false;
	}

	function modalKapat() {
		if (!modal) return;
		modal.hidden = true;
		if (form) form.reset();
		if (idEl) idEl.value = '';
		if (kaydetBtn) kaydetBtn.textContent = 'Kaydet';
		kayitUrunOrijinalSifirla();
	}

	function kayitUrunAnahtar(deger) {
		return String(deger || '').trim().toLocaleLowerCase('tr-TR');
	}

	function kayitUrunSecimleriniYaz(kayit) {
		if (!urunEl || !kayit) return;
		var hedefler = {};
		function isaretle(v) {
			var a = kayitUrunAnahtar(v);
			if (a) hedefler[a] = true;
		}
		isaretle(kayit.urun_kodu);
		isaretle(kayit.urun_adi);
		(kayit.ilgilenilen_urunler || []).forEach(isaretle);
		var secilecek = '';
		Array.prototype.forEach.call(urunEl.options, function (opt) {
			if (!opt.value) return;
			if (!secilecek && (hedefler[kayitUrunAnahtar(opt.value)] || hedefler[kayitUrunAnahtar(opt.textContent)]))
				secilecek = opt.value;
		});
		Object.keys(hedefler).forEach(function (anahtar) {
			var varMi = Array.prototype.some.call(urunEl.options, function (opt) {
				return kayitUrunAnahtar(opt.value) === anahtar || kayitUrunAnahtar(opt.textContent) === anahtar;
			});
			if (varMi) return;
			var ham = (kayit.ilgilenilen_urunler || []).find(function (ad) {
				return kayitUrunAnahtar(ad) === anahtar;
			}) || kayit.urun_adi || kayit.urun_kodu;
			if (!ham) return;
			var opt = document.createElement('option');
			opt.value = kayit.urun_kodu && kayitUrunAnahtar(kayit.urun_kodu) === anahtar ? kayit.urun_kodu : String(ham);
			opt.textContent = String(ham);
			urunEl.appendChild(opt);
			if (!secilecek) secilecek = opt.value;
		});
		urunEl.value = secilecek || '';
		var adlar = [];
		(kayit.ilgilenilen_urunler || []).forEach(function (ad) {
			if (ad) adlar.push(String(ad));
		});
		if (!adlar.length && kayit.urun_adi) adlar.push(String(kayit.urun_adi));
		var kodlar = [];
		if (kayit.urun_kodu) kodlar.push(String(kayit.urun_kodu));
		kayitUrunOrijinalAdlar = adlar;
		kayitUrunOrijinalKodlar = kodlar.length ? kodlar : (secilecek ? [secilecek] : []);
		kayitUrunIlkDeger = urunEl.value;
	}

	function kayitUrunSecimleriniAl() {
		var kodlar = [];
		var adlar = [];
		if (!urunEl) return { kodlar: kodlar, adlar: adlar };
		var val = urunEl.value;
		if (kayitUrunOrijinalAdlar.length > 1 && val === kayitUrunIlkDeger)
			return {
				kodlar: kayitUrunOrijinalKodlar.slice(),
				adlar: kayitUrunOrijinalAdlar.slice()
			};
		if (!val) return { kodlar: kodlar, adlar: adlar };
		var opt = urunEl.options[urunEl.selectedIndex];
		kodlar.push(val);
		adlar.push(String((opt && opt.textContent) || '').trim() || val);
		return { kodlar: kodlar, adlar: adlar };
	}

	function formuDoldur(kayit) {
		if (!kayit) return;
		idEl.value = kayit.id || '';
		kurumEl.value = kayit.kurum_adi || '';
		durumEl.value = durumSec(kayit.durum);
		if (abonelikTipiEl) abonelikTipiEl.value = surecTipiSec(kayit.surec_tipi || kayit.abonelik_tipi);
		notEl.value = kayit.not_icerigi || '';
		kayitUrunSecimleriniYaz(kayit);
	}

	function duzenlemeyiAc(id) {
		var yerel = kayitCache[String(id)];
		urunleriYukle().then(function () {
			if (yerel)
				formuDoldur(yerel);
			modalAc(true);
			return apiGet('/api/analizler/' + id);
		}).then(function (kayit) {
			if (kayit) {
				kayitCache[String(kayit.id)] = kayit;
				formuDoldur(kayit);
			}
		}).catch(function (err) {
			if (!yerel && hataEl) {
				hataEl.hidden = false;
				hataEl.textContent = err.message || 'Kayıt açılamadı';
			}
		});
	}

	document.getElementById('btn-kayit-ekle') && document.getElementById('btn-kayit-ekle').addEventListener('click', function () {
		if (form) form.reset();
		if (idEl) idEl.value = '';
		if (abonelikTipiEl) abonelikTipiEl.value = 'Hiçbiri';
		kayitUrunOrijinalSifirla();
		urunleriYukle().then(function () { modalAc(false); });
	});

	document.getElementById('kayit-modal-kapat') && document.getElementById('kayit-modal-kapat').addEventListener('click', modalKapat);
	document.getElementById('kayit-iptal') && document.getElementById('kayit-iptal').addEventListener('click', modalKapat);
	modal && modal.querySelector('[data-close-kayit-modal]') && modal.querySelector('[data-close-kayit-modal]').addEventListener('click', modalKapat);

	tbody.addEventListener('click', function (e) {
		var hedef = e.target;
		if (!hedef || !hedef.closest)
			return;
		var duzenle = hedef.closest('[data-action="duzenle"], .kayit-duzenle');
		var sil = hedef.closest('[data-action="sil"], .kayit-sil');
		if (duzenle) {
			e.preventDefault();
			e.stopPropagation();
			duzenlemeyiAc(duzenle.getAttribute('data-id'));
			return;
		}
		if (sil) {
			e.preventDefault();
			e.stopPropagation();
			var silId = sil.getAttribute('data-id');
			kayitSilOnayla(silId);
			return;
		}
		var satir = hedef.closest('tr[data-id]');
		if (satir)
			detayCekmecesiniAc(satir.getAttribute('data-id'));
	});

	form && form.addEventListener('submit', function (e) {
		e.preventDefault();
		var kayitId = (idEl.value || '').trim();
		var urunSecim = kayitUrunSecimleriniAl();
		var govde = {
			kurum_adi: kurumEl.value.trim(),
			urun_kodu: urunSecim.kodlar[0] || null,
			urun_adi: urunSecim.adlar[0] || null,
			durum: durumEl.value,
			surec_tipi: abonelikTipiEl ? abonelikTipiEl.value : 'Hiçbiri',
			abonelik_tipi: abonelikTipiEl ? abonelikTipiEl.value : 'Hiçbiri',
			ilgilenilen_urunler: urunSecim.adlar,
			not_icerigi: notEl.value.trim()
		};
		if (!govde.kurum_adi) {
			hataEl.hidden = false;
			hataEl.textContent = 'Kurum adı zorunludur.';
			return;
		}
		var guncelleme = Boolean(kayitId);
		var url = API_BASE + '/api/analizler' + (guncelleme ? '/' + kayitId : '');
		if (kaydetBtn) kaydetBtn.disabled = true;
		fetch(url, {
			method: guncelleme ? 'PUT' : 'POST',
			headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
			body: JSON.stringify(govde)
		})
			.then(function (r) { return r.text().then(function (raw) { return jsonAl(r, raw); }); })
			.then(function () {
				modalKapat();
				return yukleKayitTablosu();
			})
			.then(function () {
				if (typeof window.loadGlobalStats === 'function')
					window.loadGlobalStats();
			})
			.catch(function (err) {
				hataEl.hidden = false;
				hataEl.textContent = err.message || (guncelleme ? 'Güncelleme başarısız' : 'Kayıt kaydedilemedi');
			})
			.then(function () {
				if (kaydetBtn) kaydetBtn.disabled = false;
			});
	});

	// AI analizi bittiğinde yeni kaydın detay/düzenleme modalını otomatik
	// açmak için (bkz. ikinci IIFE'deki calistirAnaliz) global olarak sunulur.
	window.yukleKayitTablosu = yukleKayitTablosu;
	window.yukleVeritabaniTablolari = yukleVeritabaniTablolari;
	window.crmKayitDetayiniAc = detayCekmecesiniAc;
	window.crmDrawerKurumAc = kurumCekmecesiniAc;
	window.crmKayitDuzenle = duzenlemeyiAc;
	window.crmKolonFiltreAc = kolonFiltreMenuAc;
	window.crmKolonFiltreKapat = kolonFiltrePopoverKapat;
	window.crmBenzersizSirali = benzersizSirali;
	if (document.getElementById('drawer-kapat'))
		document.getElementById('drawer-kapat').addEventListener('click', drawerKapat);
	if (drawer && drawer.querySelector('[data-close-drawer]'))
		drawer.querySelector('[data-close-drawer]').addEventListener('click', drawerKapat);
	if (drawerDuzenle) {
		drawerDuzenle.addEventListener('click', function () {
			var id = drawerKayitId;
			if (!id) {
				if (typeof window.gosterToast === 'function')
					window.gosterToast('Bu görünümde düzenlenecek görüşme kaydı yok.', 'hata');
				return;
			}
			drawerKapatHemen();
			duzenlemeyiAc(id);
		});
	}
	if (drawerSil) {
		drawerSil.addEventListener('click', function (e) {
			if (e) {
				e.preventDefault();
				e.stopPropagation();
			}
			var id = drawerKayitId || (drawer && drawer.getAttribute('data-id'));
			if (!id) {
				if (typeof window.gosterToast === 'function')
					window.gosterToast('Silinecek görüşme kaydı bulunamadı.', 'hata');
				return;
			}
			kayitSilOnayla(id);
		});
	}
	document.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && drawer && !drawer.hidden)
			drawerKapat();
	});
	urunleriYukle();
	surecTipleriYukle();
	yukleKayitTablosu();
	temaToggleBaslat();
	bildirimCaniniBaslat();
})();

// Sol menü (sidebar) sekme geçişi: "Görüşmeler" (mevcut kartlı/filtreli
// dashboard) ve "Veritabanı" (tüm kayıtların geniş tablo görünümü) arasında
// geçiş yapar. Sayfa tek bir index.html olarak kalır; hiçbir fetch/axios
// mantığı değişmez, sadece görünürlük (hidden) değiştirilir. Sekme durumu
// URL hash'inde (#veritabani) saklanır ki sayfa yenilendiğinde korunsun.
(function () {
	'use strict';

	var navLinks = Array.prototype.slice.call(document.querySelectorAll('.crm-app-nav-link'));
	var panels = Array.prototype.slice.call(document.querySelectorAll('[data-view-panel]'));

	if (!navLinks.length || !panels.length)
		return;

	function hashdenView(hash) {
		var view = String(hash || '').replace(/^#/, '').trim();
		if (!view)
			return 'gorusmeler';
		return view;
	}

	function viewIcinUrl(view) {
		return location.pathname + location.search + (view === 'gorusmeler' ? '' : ('#' + view));
	}

	function suankiUrl() {
		return location.pathname + location.search + (location.hash || '');
	}

	function gecersizViewMi(view) {
		return !navLinks.some(function (l) { return l.getAttribute('data-view') === view; });
	}

	var aktifView = hashdenView(location.hash);
	if (gecersizViewMi(aktifView))
		aktifView = 'gorusmeler';

	function acikKatmanlariKapat() {
		var drawer = document.getElementById('kayit-drawer');
		if (drawer && !drawer.hidden) {
			drawer.classList.remove('is-open');
			drawer.hidden = true;
		}
		['kayit-modal', 'fab-gorev-modal', 'stats-modal', 'kurum-modal'].forEach(function (id) {
			var el = document.getElementById(id);
			if (el && !el.hidden)
				el.hidden = true;
		});
	}

	function sekmeyiAc(view, guncelleHash) {
		var isAdmin = window.Auth && window.Auth.isAdmin && window.Auth.isAdmin();
		var istenen = view;
		if ((view === 'kullanici-yonetimi' || view === 'urunler') && !isAdmin)
			view = 'gorusmeler';

		var bulunduMu = false;
		panels.forEach(function (panel) {
			var aktif = panel.getAttribute('data-view-panel') === view;
			if (aktif) bulunduMu = true;
			panel.hidden = !aktif;
		});
		if (!bulunduMu)
			return;

		var onceki = aktifView;
		if (onceki !== view)
			acikKatmanlariKapat();
		aktifView = view;

		navLinks.forEach(function (link) {
			var aktif = link.getAttribute('data-view') === view;
			link.classList.toggle('is-active', aktif);
			if (aktif)
				link.setAttribute('aria-current', 'page');
			else
				link.removeAttribute('aria-current');
		});

		if (guncelleHash !== false) {
			var hedef = viewIcinUrl(view);
			if (suankiUrl() !== hedef) {
				try {
					if (onceki === view || istenen !== view)
						history.replaceState({ view: view }, '', hedef);
					else
						history.pushState({ view: view }, '', hedef);
				} catch (e) {}
			}
		}

		if (typeof window.yukleKayitTablosu === 'function' &&
			(view === 'kurumlar' || view === 'gorusmeler' || view === 'notlarim' ||
			 view === 'gorusme-listesi' || view === 'urunler'))
			window.yukleKayitTablosu();
		if (view === 'veritabani' && typeof window.yukleVeritabaniTablolari === 'function')
			window.yukleVeritabaniTablolari();
		if (view === 'gorevler') {
			if (typeof window.crmGorevleriYenile === 'function')
				window.crmGorevleriYenile().catch(function () {});
			else if (typeof window.crmTodosYenile === 'function')
				window.crmTodosYenile();
		}
		if ((view === 'gorusmeler' || view === 'gorevler') &&
			typeof window.crmAdminAtamaPanelleriniHazirla === 'function')
			window.crmAdminAtamaPanelleriniHazirla();
		try {
			document.dispatchEvent(new CustomEvent('crm-view-change', { detail: { view: view } }));
		} catch (e) {}
		menuyuKapat();
	}

	function gecmisdenAc() {
		var view = hashdenView(location.hash);
		if (gecersizViewMi(view))
			view = 'gorusmeler';
		if (view === aktifView)
			return;
		sekmeyiAc(view, false);
	}

	window.addEventListener('popstate', gecmisdenAc);
	window.addEventListener('hashchange', gecmisdenAc);

	function menuAcikMi() {
		return document.body.classList.contains('crm-nav-open');
	}

	function menuyuAc() {
		document.body.classList.add('crm-nav-open');
		if (navToggle) {
			navToggle.setAttribute('aria-expanded', 'true');
			navToggle.setAttribute('aria-label', 'Menüyü kapat');
		}
		if (navBackdrop) navBackdrop.hidden = false;
	}

	function menuyuKapat() {
		document.body.classList.remove('crm-nav-open');
		if (navToggle) {
			navToggle.setAttribute('aria-expanded', 'false');
			navToggle.setAttribute('aria-label', 'Menüyü aç');
		}
		if (navBackdrop) navBackdrop.hidden = true;
	}

	var navToggle = document.getElementById('nav-toggle');
	var navBackdrop = document.getElementById('crm-nav-backdrop');
	if (navToggle) {
		navToggle.addEventListener('click', function () {
			if (menuAcikMi())
				menuyuKapat();
			else
				menuyuAc();
		});
	}
	if (navBackdrop) {
		navBackdrop.addEventListener('click', menuyuKapat);
	}
	document.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && menuAcikMi())
			menuyuKapat();
	});

	window.crmSekmeyiAc = function (view) {
		sekmeyiAc(view);
	};

	navLinks.forEach(function (link) {
		link.addEventListener('click', function () {
			sekmeyiAc(link.getAttribute('data-view'));
		});
	});

	var baslangicView = hashdenView(location.hash);
	if (baslangicView !== 'gorusmeler' && !gecersizViewMi(baslangicView))
		sekmeyiAc(baslangicView, false);
})();

// ── Admin: Kullanıcı Yönetimi ─────────────────────────────────────────────
(function () {
	'use strict';
	var API_BASE = CRM_API;

	var form = document.getElementById('yeni-kullanici-form');
	var hataEl = document.getElementById('yk-hata');
	var basariEl = document.getElementById('yk-basari');
	var liste = document.getElementById('kullanici-liste-yukleniyor');
	var tablo = document.getElementById('kullanici-tablosu');
	var tbody = document.getElementById('kullanici-tbody');
	var sirketSelect = document.getElementById('yk-sirket');
	var sirketHaritasi = {};
	var kullaniciListeCache = [];
	var kullaniciSorgu = { q: '', rol: '', sirket: '', sort: 'ad', dir: 'asc' };

	if (!form) return; // Sayfa yüklenmemişse çık

	function kacisHtml(metin) {
		return String(metin == null ? '' : metin)
			.replace(/&/g, '&amp;')
			.replace(/</g, '&lt;')
			.replace(/>/g, '&gt;')
			.replace(/"/g, '&quot;');
	}

	function sirketleriYukle() {
		if (!sirketSelect) return Promise.resolve();
		return fetch(API_BASE + '/api/companies', { headers: { Accept: 'application/json' } })
			.then(function (r) { return r.json(); })
			.then(function (data) {
				var sirketler = data.sirketler || [];
				sirketHaritasi = {};
				sirketSelect.innerHTML = '<option value="">Şirket seçin...</option>';
				sirketler.forEach(function (s) {
					sirketHaritasi[s.id] = s.name;
					var opt = document.createElement('option');
					opt.value = String(s.id);
					opt.textContent = s.name;
					sirketSelect.appendChild(opt);
				});
				if (sirketler.length === 1)
					sirketSelect.value = String(sirketler[0].id);
			})
			.catch(function () {
				if (sirketSelect.options.length <= 1)
					sirketSelect.innerHTML = '<option value="">Şirketler yüklenemedi</option>';
			});
	}

	function kullaniciTablosunuCiz() {
		if (!tablo || !tbody) return;
		var Q = window.CrmQuery;
		var st = kullaniciSorgu;
		var ham = kullaniciListeCache.slice();
		var liste = ham.filter(function (u) {
			var sirketAd = (u.company_id && sirketHaritasi[u.company_id])
				? sirketHaritasi[u.company_id]
				: (u.company_id ? ('#' + u.company_id) : '');
			if (st.rol && String(u.role || '') !== st.rol)
				return false;
			if (st.sirket && sirketAd !== st.sirket)
				return false;
			return !Q || Q.match(st.q, [u.ad_soyad, u.email, u.kullanici_adi, sirketAd, u.role]);
		});
		if (Q) {
			liste.sort(function (a, b) {
				var av, bv;
				if (st.sort === 'id') { av = Number(a.id) || 0; bv = Number(b.id) || 0; }
				else if (st.sort === 'kadi') { av = a.kullanici_adi; bv = b.kullanici_adi; }
				else if (st.sort === 'email') { av = a.email; bv = b.email; }
				else if (st.sort === 'sirket') {
					av = (a.company_id && sirketHaritasi[a.company_id]) || '';
					bv = (b.company_id && sirketHaritasi[b.company_id]) || '';
				} else if (st.sort === 'rol') { av = a.role; bv = b.role; }
				else { av = a.ad_soyad || a.kullanici_adi; bv = b.ad_soyad || b.kullanici_adi; }
				return Q.cmp(av, bv, st.dir);
			});
			Q.paintSort(tablo, st);
			Q.paintColFilter(tablo, st, ['rol', 'sirket']);
		}
		var rolSel = document.getElementById('kullanici-filtre-rol');
		if (rolSel && rolSel.value !== (st.rol || ''))
			rolSel.value = st.rol || '';
		var sonucEl = document.getElementById('kullanici-sonuc');
		if (sonucEl) {
			sonucEl.textContent = ham.length
				? (liste.length === ham.length ? (ham.length + ' kayıt') : (liste.length + ' / ' + ham.length + ' kayıt'))
				: '';
		}
		tbody.innerHTML = '';
		if (!liste.length) {
			var trBos = document.createElement('tr');
			trBos.innerHTML = '<td colspan="7">' +
				(st.q || st.rol ? 'Aramayla eşleşen kullanıcı yok.' : 'Henüz kullanıcı yok.') +
			'</td>';
			tbody.appendChild(trBos);
			tablo.hidden = false;
			return;
		}
		liste.forEach(function (u) {
			var tr = document.createElement('tr');
			var rolBadge = u.role === 'admin'
				? '<span class="crm-rol-badge is-admin">Admin</span>'
				: '<span class="crm-rol-badge is-user">Kullanıcı</span>';
			var silBtn = u.role !== 'admin'
				? '<button class="crm-sil-btn" data-id="' + kacisHtml(u.id) + '" data-kadi="' + kacisHtml(u.kullanici_adi) + '">Sil</button>'
				: '<span style="color:rgba(255,255,255,0.25);font-size:.78rem">—</span>';
			var sirketAd = (u.company_id && sirketHaritasi[u.company_id])
				? sirketHaritasi[u.company_id]
				: (u.company_id ? ('#' + u.company_id) : '—');
			tr.innerHTML = '<td>' + kacisHtml(u.id) + '</td>'
				+ '<td>' + kacisHtml(u.kullanici_adi || '—') + '</td>'
				+ '<td>' + kacisHtml(u.ad_soyad || '—') + '</td>'
				+ '<td>' + kacisHtml(u.email || '—') + '</td>'
				+ '<td>' + kacisHtml(sirketAd) + '</td>'
				+ '<td>' + rolBadge + '</td>'
				+ '<td>' + silBtn + '</td>';
			tbody.appendChild(tr);
		});
		tablo.hidden = false;
		tbody.querySelectorAll('.crm-sil-btn').forEach(function (btn) {
			btn.addEventListener('click', function () {
				var id = btn.dataset.id;
				var kadi = btn.dataset.kadi;
				if (!confirm('"' + kadi + '" kullanıcısını silmek istediğinize emin misiniz?')) return;
				fetch(API_BASE + '/api/kullanicilar/' + id, { method: 'DELETE', headers: { Accept: 'application/json' } })
					.then(function (r) { return r.json(); })
					.then(function () { kullanicilariYukle(); })
					.catch(function (err) { alert('Silinemedi: ' + err.message); });
			});
		});
	}

	function kullanicilariYukle() {
		if (liste) { liste.style.display = ''; liste.textContent = 'Yükleniyor...'; }
		if (tablo) tablo.hidden = true;
		fetch(API_BASE + '/api/kullanicilar', { headers: { Accept: 'application/json' } })
			.then(function (r) { return r.json(); })
			.then(function (data) {
				if (liste) liste.style.display = 'none';
				kullaniciListeCache = data.kullanicilar || [];
				kullaniciTablosunuCiz();
			})
			.catch(function (err) {
				if (liste) { liste.style.display = ''; liste.textContent = 'Yüklenemedi: ' + err.message; }
			});
	}

	function kullaniciKolonDegerleri(kolon) {
		var benzersiz = window.crmBenzersizSirali || function (a) { return a; };
		if (kolon === 'rol')
			return benzersiz((kullaniciListeCache || []).map(function (u) { return u.role; }));
		if (kolon === 'sirket') {
			return benzersiz((kullaniciListeCache || []).map(function (u) {
				return (u.company_id && sirketHaritasi[u.company_id]) || '';
			}));
		}
		return [];
	}

	(function kullaniciAramaBagla() {
		var Q = window.CrmQuery;
		var arama = document.getElementById('kullanici-arama');
		var rol = document.getElementById('kullanici-filtre-rol');
		var t;
		if (arama) {
			arama.addEventListener('input', function () {
				clearTimeout(t);
				t = setTimeout(function () {
					kullaniciSorgu.q = arama.value || '';
					kullaniciTablosunuCiz();
				}, 80);
			});
		}
		if (rol) {
			rol.addEventListener('change', function () {
				kullaniciSorgu.rol = rol.value || '';
				kullaniciTablosunuCiz();
			});
		}
		if (tablo && Q) {
			tablo.addEventListener('click', function (e) {
				var btn = e.target.closest ? e.target.closest('.crm-sort-btn') : null;
				if (!btn || !tablo.contains(btn)) return;
				e.preventDefault();
				var sortKey = btn.getAttribute('data-sort');
				var filterKey = btn.getAttribute('data-col-filter');
				if (filterKey && !(e.target.closest && e.target.closest('.crm-sort-icon'))) {
					var degerler = kullaniciKolonDegerleri(filterKey);
					var baslik = filterKey === 'rol' ? 'Rol' : 'Şirket';
					var secili = kullaniciSorgu[filterKey] || '';
					if (typeof window.crmKolonFiltreAc === 'function') {
						window.crmKolonFiltreAc(btn, baslik, degerler, secili, function (val) {
							kullaniciSorgu[filterKey] = val || '';
							if (filterKey === 'rol' && rol)
								rol.value = val || '';
							kullaniciTablosunuCiz();
						});
					}
					return;
				}
				if (typeof window.crmKolonFiltreKapat === 'function')
					window.crmKolonFiltreKapat();
				Q.toggleSort(kullaniciSorgu, sortKey);
				kullaniciTablosunuCiz();
			});
		}
	})();

	document.addEventListener('crm-view-change', function (e) {
		if (e.detail && e.detail.view === 'kullanici-yonetimi') {
			sirketleriYukle().then(kullanicilariYukle);
		}
	});

	if (window.location.hash === '#kullanici-yonetimi') {
		sirketleriYukle().then(kullanicilariYukle);
	} else {
		sirketleriYukle();
	}

	form.addEventListener('submit', function (e) {
		e.preventDefault();
		if (hataEl) { hataEl.hidden = true; hataEl.textContent = ''; }
		if (basariEl) { basariEl.style.display = 'none'; basariEl.textContent = ''; }
		var kadi = (document.getElementById('yk-kadi') || {}).value || '';
		var ad = (document.getElementById('yk-ad') || {}).value || '';
		var email = (document.getElementById('yk-email') || {}).value || '';
		var sirketId = (document.getElementById('yk-sirket') || {}).value || '';
		var sifre = (document.getElementById('yk-sifre') || {}).value || '';
		if (!kadi.trim() || !sifre) {
			if (hataEl) { hataEl.textContent = 'Kullanıcı adı ve şifre zorunludur.'; hataEl.hidden = false; }
			return;
		}
		if (!email.trim() || email.indexOf('@') < 0) {
			if (hataEl) { hataEl.textContent = 'Geçerli bir e-posta adresi girin.'; hataEl.hidden = false; }
			return;
		}
		if (!sirketId) {
			if (hataEl) { hataEl.textContent = 'Lütfen bir şirket seçin.'; hataEl.hidden = false; }
			return;
		}
		fetch(API_BASE + '/api/kullanicilar', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
			body: JSON.stringify({
				kullanici_adi: kadi.trim(),
				ad_soyad: ad.trim() || null,
				sifre: sifre,
				role: 'user',
				email: email.trim().toLowerCase(),
				company_id: parseInt(sirketId, 10)
			}),
		})
		.then(function (r) { return r.json().then(function (d) { return { ok: r.ok, data: d }; }); })
		.then(function (res) {
			if (!res.ok) {
				var detay = res.data && res.data.detail;
				if (Array.isArray(detay))
					detay = detay.map(function (x) { return x.msg || JSON.stringify(x); }).join(' ');
				if (hataEl) { hataEl.textContent = detay || 'Hata oluştu.'; hataEl.hidden = false; }
				return;
			}
			if (basariEl) { basariEl.textContent = '✓ ' + (res.data.mesaj || 'Kullanıcı oluşturuldu.'); basariEl.style.display = ''; }
			form.reset();
			sirketleriYukle().then(kullanicilariYukle);
		})
		.catch(function (err) {
			if (hataEl) { hataEl.textContent = err.message || 'Sunucuya bağlanılamadı.'; hataEl.hidden = false; }
		});
	});
})();

// ── FAB + Ana sayfa: Yeni Görev Ekle ──────────────────────────────────────
(function () {
	'use strict';
	var fab = document.getElementById('fab-yeni-gorev');
	var dashBtn = document.getElementById('btn-dash-gorev-ekle');
	var modal = document.getElementById('fab-gorev-modal');
	var form = document.getElementById('fab-gorev-form');
	var baslikEl = document.getElementById('fab-gorev-baslik');
	var tarihEl = document.getElementById('fab-gorev-tarih');
	var hataEl = document.getElementById('fab-gorev-hata');
	var kapatBtn = document.getElementById('fab-gorev-kapat');
	var iptalBtn = document.getElementById('fab-gorev-iptal');
	var tabsEl = document.getElementById('fab-gorev-tabs');
	var personelAlan = document.getElementById('fab-gorev-personele-alan');
	var urunEl = document.getElementById('fab-gorev-urun');
	var calisanEl = document.getElementById('fab-gorev-calisan');
	var etiketEl = document.getElementById('fab-gorev-baslik-etiket');
	var kaydetBtn = document.getElementById('fab-gorev-kaydet');
	var fabMod = 'kendime';
	if (!modal || !form) return;

	function adminMi() {
		return !!(window.Auth && window.Auth.isAdmin && window.Auth.isAdmin());
	}

	function calisanSifirla() {
		if (!calisanEl) return;
		calisanEl.innerHTML = '<option value="">Önce ürün seçin</option>';
		calisanEl.disabled = true;
		calisanEl.value = '';
	}

	function fabModGuncelle() {
		var admin = adminMi();
		if (!admin)
			fabMod = 'kendime';
		if (tabsEl)
			tabsEl.hidden = !admin;
		if (tabsEl) {
			var butonlar = tabsEl.querySelectorAll('[data-fab-composer]');
			var i;
			for (i = 0; i < butonlar.length; i++)
				butonlar[i].classList.toggle('is-active', butonlar[i].getAttribute('data-fab-composer') === fabMod);
		}
		if (personelAlan)
			personelAlan.hidden = !admin || fabMod !== 'personele';
		if (etiketEl)
			etiketEl.textContent = fabMod === 'personele' ? 'Görev' : 'Görev (size atanır)';
		if (kaydetBtn)
			kaydetBtn.textContent = fabMod === 'personele' ? 'Ata' : 'Ekle';
	}

	function ac() {
		fabMod = 'kendime';
		modal.hidden = false;
		if (hataEl) { hataEl.hidden = true; hataEl.textContent = ''; }
		calisanSifirla();
		fabModGuncelle();
		if (adminMi() && urunEl && urunEl.options.length <= 1 && typeof window.crmAdminAtamaPanelleriniHazirla === 'function')
			window.crmAdminAtamaPanelleriniHazirla();
		window.setTimeout(function () {
			if (baslikEl) baslikEl.focus();
		}, 50);
	}

	function kapat() {
		modal.hidden = true;
		form.reset();
		fabMod = 'kendime';
		calisanSifirla();
		fabModGuncelle();
		if (hataEl) { hataEl.hidden = true; hataEl.textContent = ''; }
	}

	window.crmGorevEkleAc = ac;

	if (tabsEl) {
		tabsEl.addEventListener('click', function (e) {
			var btn = e.target.closest ? e.target.closest('[data-fab-composer]') : null;
			if (!btn || !tabsEl.contains(btn))
				return;
			e.preventDefault();
			var mod = btn.getAttribute('data-fab-composer');
			if (mod !== 'kendime' && mod !== 'personele')
				return;
			fabMod = mod;
			if (hataEl) { hataEl.hidden = true; hataEl.textContent = ''; }
			fabModGuncelle();
			if (fabMod === 'personele' && urunEl)
				urunEl.focus();
			else if (baslikEl)
				baslikEl.focus();
		});
	}

	if (fab) {
		fab.addEventListener('click', function (e) {
			e.preventDefault();
			ac();
		});
	}
	if (dashBtn) {
		dashBtn.addEventListener('click', function (e) {
			e.preventDefault();
			ac();
		});
	}
	if (kapatBtn) kapatBtn.addEventListener('click', kapat);
	if (iptalBtn) iptalBtn.addEventListener('click', kapat);
	modal.querySelectorAll('[data-close-fab-gorev]').forEach(function (el) {
		el.addEventListener('click', kapat);
	});

	form.addEventListener('submit', function (e) {
		e.preventDefault();
		var baslik = String((baslikEl && baslikEl.value) || '').trim();
		var due = tarihEl ? String(tarihEl.value || '').trim() : '';
		if (!baslik) {
			if (hataEl) { hataEl.textContent = 'Görev metnini yazın.'; hataEl.hidden = false; }
			return;
		}
		var atanan = null;
		var urunId = null;
		if (fabMod === 'personele') {
			urunId = urunEl ? String(urunEl.value || '').trim() : '';
			atanan = calisanEl ? String(calisanEl.value || '').trim() : '';
			if (!urunId) {
				if (hataEl) { hataEl.textContent = 'Önce ürün seçin.'; hataEl.hidden = false; }
				if (urunEl) urunEl.focus();
				return;
			}
			if (!atanan) {
				if (hataEl) { hataEl.textContent = 'Çalışan seçin.'; hataEl.hidden = false; }
				if (calisanEl) calisanEl.focus();
				return;
			}
		}
		var btn = kaydetBtn || form.querySelector('button[type="submit"]');
		var kaydet = window.crmBagimsizGorevKaydet;
		if (typeof kaydet !== 'function') {
			if (hataEl) { hataEl.textContent = 'Görev kaydı hazır değil.'; hataEl.hidden = false; }
			return;
		}
		kaydet(baslik, due, btn, atanan, urunId).then(function () {
			kapat();
		}).catch(function (err) {
			if (hataEl) {
				hataEl.textContent = (err && err.message) || 'Görev eklenemedi.';
				hataEl.hidden = false;
			}
		});
	});
})();
