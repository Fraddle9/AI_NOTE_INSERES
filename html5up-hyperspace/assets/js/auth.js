/**
 * auth.js — JWT kimlik doğrulama katmanı (Web / CRM Analiz Portalı)
 *
 * Sorumluluklar:
 *  1. localStorage'daki token'ı okuyup sayfayı Login'e yönlendir
 *  2. Tüm fetch çağrılarına Authorization: Bearer <token> header'ı ekle
 *  3. 401 yanıtı gelince otomatik çıkış yap
 *  4. window.Auth API'sini açığa çıkar (login, logout, getToken, getUser)
 */
(function () {
  'use strict';

  var TOKEN_KEY   = 'crm-auth-token';
  var USER_KEY    = 'crm-auth-user';
  var LOGIN_PAGE  = 'login.html';
  var API_BASE    = (window.CRM_API_BASE || 'http://127.0.0.1:8000').replace(/\/$/, '');

  /* ── Yardımcılar ────────────────────────────────────────────────────── */

  function tokenAl()   { try { return localStorage.getItem(TOKEN_KEY); }    catch(e){ return null; } }
  function kullAl()    { try { return JSON.parse(localStorage.getItem(USER_KEY) || 'null'); } catch(e){ return null; } }
  function tokenKaydet(t, u) {
    try {
      localStorage.setItem(TOKEN_KEY, t);
      localStorage.setItem(USER_KEY, JSON.stringify(u || {}));
    } catch(e) {}
  }
  function tokenSil() {
    try { localStorage.removeItem(TOKEN_KEY); localStorage.removeItem(USER_KEY); } catch(e) {}
  }
  function loginSayfasi() {
    if (!window.location.pathname.endsWith(LOGIN_PAGE))
      window.location.href = LOGIN_PAGE;
  }

  /* ── Fetch Interceptor ──────────────────────────────────────────────── */
  // Orijinal fetch'i sarak tüm isteklere otomatik Bearer header ekler.
  // 401 gelirse token silinip login sayfasına yönlendirilir.
  var _originalFetch = window.fetch;
  window.fetch = function (url, options) {
    options = options || {};
    var token = tokenAl();
    if (token) {
      options.headers = options.headers || {};
      // Headers nesnesi veya düz obje olabilir
      if (typeof options.headers.set === 'function') {
        options.headers.set('Authorization', 'Bearer ' + token);
      } else {
        options.headers['Authorization'] = 'Bearer ' + token;
      }
    }
    return _originalFetch.call(window, url, options).then(function (response) {
      if (response.status === 401) {
        tokenSil();
        loginSayfasi();
      }
      return response;
    });
  };

  /* ── Sayfa Koruma ───────────────────────────────────────────────────── */
  // login.html harici her sayfada token zorunlu.
  (function koru() {
    if (window.location.pathname.endsWith(LOGIN_PAGE)) return;
    if (!tokenAl()) { loginSayfasi(); }
  })();

  /* ── Public API ─────────────────────────────────────────────────────── */
  window.Auth = {
    /**
     * Backend'den token alır, saklar, ana sayfaya yönlendirir.
     * @param {string} kullanici_adi
     * @param {string} sifre
     * @returns {Promise<object>} token yanıtı
     */
    login: function (kullanici_adi, sifre) {
      return _originalFetch(API_BASE + '/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({ kullanici_adi: kullanici_adi, sifre: sifre }),
      }).then(function (r) {
        return r.json().then(function (data) {
          if (!r.ok) throw new Error(data.detail || 'Giriş başarısız');
          tokenKaydet(data.access_token, {
            kullanici_adi: data.kullanici_adi,
            ad_soyad: data.ad_soyad || data.kullanici_adi,
            role: data.role || 'user',
            id: data.id || null,
            company_id: data.company_id || null,
          });
          return data;
        });
      });
    },

    /** Token + kullanıcı bilgisini siler, login sayfasına döner. */
    logout: function () {
      var bitti = false;
      function bitir() {
        if (bitti) return;
        bitti = true;
        tokenSil();
        loginSayfasi();
      }
      if (window.CrmWebFcm && typeof window.CrmWebFcm.tokenuSil === 'function') {
        window.CrmWebFcm.tokenuSil().then(bitir, bitir);
        window.setTimeout(bitir, 2500);
      } else {
        bitir();
      }
    },

    /** Mevcut JWT token'ı döndürür (yoksa null). */
    getToken: function () { return tokenAl(); },

    /** Oturum açmış kullanıcı bilgisini döndürür (yoksa null). */
    getUser: function () { return kullAl(); },

    /** Oturum açık mı? */
    isAuthenticated: function () { return !!tokenAl(); },

    /** Oturum açan kullanıcı admin mi? */
    isAdmin: function () {
      var u = kullAl();
      return !!(u && u.role === 'admin');
    },

    /**
     * Özgür kayıt: backend'de role=user hesabı açar, token saklar.
     * @param {string} kullanici_adi
     * @param {string} sifre
     * @param {string} [ad_soyad]
     * @returns {Promise<object>}
     */
    register: function (kullanici_adi, sifre, ad_soyad) {
      return _originalFetch(API_BASE + '/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
        body: JSON.stringify({
          kullanici_adi: kullanici_adi,
          sifre: sifre,
          ad_soyad: ad_soyad || null,
        }),
      }).then(function (r) {
        return r.json().then(function (data) {
          if (!r.ok) throw new Error(data.detail || 'Kayıt başarısız');
          tokenKaydet(data.access_token, {
            kullanici_adi: data.kullanici_adi,
            ad_soyad: data.ad_soyad || data.kullanici_adi,
            role: data.role || 'user',
            id: data.id || null,
            company_id: data.company_id || null,
          });
          return data;
        });
      });
    },

    /** Sunucudan güncel kullanıcı (rol) bilgisini çekip localStorage'a yazar. */
    refreshUser: function () {
      return window.fetch(API_BASE + '/api/ben', {
        headers: { Accept: 'application/json' },
      }).then(function (r) {
        return r.json().then(function (data) {
          if (!r.ok) throw new Error(data.detail || 'Oturum doğrulanamadı');
          var mevcut = kullAl() || {};
          tokenKaydet(tokenAl(), {
            kullanici_adi: data.kullanici_adi || mevcut.kullanici_adi,
            ad_soyad: data.ad_soyad || mevcut.ad_soyad,
            role: data.role || 'user',
            id: data.id || mevcut.id || null,
            company_id: data.company_id != null ? data.company_id : (mevcut.company_id || null),
          });
          return data;
        });
      });
    },

    /**
     * Oturum açmış kullanıcının görünen adını günceller (kullanıcı adı değişmez).
     * @param {string} ad_soyad
     */
    updateProfile: function (ad_soyad) {
      return window.fetch(API_BASE + '/api/profil', {
        method: 'PUT',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ ad_soyad: ad_soyad }),
      }).then(function (r) {
        return r.json().then(function (data) {
          if (!r.ok) {
            var detay = data && data.detail;
            if (Array.isArray(detay))
              detay = detay.map(function (x) { return x.msg || JSON.stringify(x); }).join(' ');
            throw new Error(detay || 'Profil güncellenemedi');
          }
          var mevcut = kullAl() || {};
          tokenKaydet(tokenAl(), {
            kullanici_adi: data.kullanici_adi || mevcut.kullanici_adi,
            ad_soyad: data.ad_soyad || mevcut.ad_soyad,
            role: data.role || mevcut.role || 'user',
            id: data.id || mevcut.id || null,
            company_id: data.company_id != null ? data.company_id : (mevcut.company_id || null),
          });
          return data;
        });
      });
    },

    /**
     * Oturum açmış kullanıcının şifresini günceller (kullanıcı adı değişmez).
     * @param {string} mevcut_sifre
     * @param {string} yeni_sifre
     */
    changePassword: function (mevcut_sifre, yeni_sifre) {
      return window.fetch(API_BASE + '/api/sifre', {
        method: 'PUT',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ mevcut_sifre: mevcut_sifre, yeni_sifre: yeni_sifre }),
      }).then(function (r) {
        return r.json().then(function (data) {
          if (!r.ok) {
            var detay = data && data.detail;
            if (Array.isArray(detay))
              detay = detay.map(function (x) { return x.msg || JSON.stringify(x); }).join(' ');
            throw new Error(detay || 'Şifre güncellenemedi');
          }
          if (data && data.access_token)
            tokenKaydet(data.access_token, kullAl());
          return data;
        });
      });
    },

    /** Yalnızca token günceller (şifre değişimi sonrası). */
    setToken: function (token) {
      if (token) tokenKaydet(token, kullAl());
    },
  };

})();
