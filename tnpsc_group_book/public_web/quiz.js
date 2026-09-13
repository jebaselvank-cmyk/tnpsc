/**
 * TNPSC Master - Ultimate Robust Router
 * Fixes: Row count mismatch (16 to 20), Multi-line CSV parsing
 */

const CONFIG = {
    sheetUrl: 'https://docs.google.com/spreadsheets/d/e/2PACX-1vSnufG0r1c65d6DOXTX8ssI0sDhfKYVRehjAKg7LerHdq8ZfIk2hz3FI5cQNdehsAVfqf7Yr6XLrk9E/pub?gid=0&single=true&output=csv',
    istOffset: 5.5 * 60 * 60 * 1000,
    adsense: {
        publisherId: 'ca-pub-9952621231526514',
        bannerSlot: '1111111111',
        inlineSlot: '2222222222',
        resultSlot: '3333333333'
    },
    firebase: {
        apiKey: 'AIzaSyAts3EGWRa46AnKXuKMyD2LFTarDYu8PJ4',
        appId: '1:384136070006:web:1996145989d72321fd7057',
        messagingSenderId: '384136070006',
        projectId: 'tnpsc-prepare-app-koilra-c9998',
        authDomain: 'tnpsc-prepare-app-koilra-c9998.firebaseapp.com',
        storageBucket: 'tnpsc-prepare-app-koilra-c9998.firebasestorage.app',
    }
};

let db = null;
let allQuizzes = [];
let realLeaderboard = [];
let latestNotification = null;
let currentQuiz = null;
let currentQuestionIndex = 0;
let score = 0;
let activeDate = null;
let currentLang = 'en'; // Changed default to English

document.addEventListener('DOMContentLoaded', () => {
    initApp();
    window.addEventListener('hashchange', () => handleRouting());
});

function toggleLanguage() {
    currentLang = currentLang === 'ta' ? 'en' : 'ta';
    handleRouting();
}

async function initApp() {
    showLoading(true);
    try {
        // Initialize Firebase
        if (typeof firebase !== 'undefined') {
            firebase.initializeApp(CONFIG.firebase);
            db = firebase.firestore();
            console.log("Firebase initialized");

            // Fetch real data in background
            fetchRealLeaderboard();
            fetchRealNotifications();
        }

        await fetchQuizData();
        if (allQuizzes.length === 0) {
            showError("No data found.");
            return;
        }
        if (!window.location.hash) window.location.hash = 'home';
        else handleRouting();
    } catch (error) {
        console.error("Init Error:", error);
        showError("Data Error. Please refresh.");
    } finally {
        showLoading(false);
    }
}

async function fetchRealLeaderboard() {
    if (!db) return;
    try {
        const todayStr = new Date(new Date().getTime() + CONFIG.istOffset).toISOString().split('T')[0];
        console.log("Fetching Daily Quiz Leaderboard for:", todayStr);

        // Listen ONLY to Daily Quiz leaderboard for today
        db.collection('leaderboards')
            .doc('daily_' + todayStr)
            .collection('scores')
            .orderBy('score', 'desc')
            .limit(3)
            .onSnapshot((snap) => {
                if (!snap.empty) {
                    realLeaderboard = snap.docs.map(doc => doc.data());
                } else {
                    realLeaderboard = [];
                }
                // Refresh UI
                if (window.location.hash === '#home' || window.location.hash === '' || !window.location.hash) renderHomeUI();
            }, (error) => {
                console.error("Leaderboard error:", error);
            });

    } catch (e) {
        console.log("Leaderboard setup error:", e);
    }
}

async function fetchRealNotifications() {
    if (!db) return;
    try {
        // Fetch most recent notification from current_affairs_points
        const snap = await db.collection('current_affairs_points')
            .orderBy('timestamp', 'desc')
            .limit(1)
            .get();

        if (!snap.empty) {
            latestNotification = snap.docs[0].data();
            if (window.location.hash === '#home') renderHomeUI();
        }
    } catch (e) {
        console.log("Notification fetch error:", e);
    }
}

function handleRouting() {
    const hash = window.location.hash.substring(1) || 'home';
    const parts = hash.split('/');
    const page = parts[0];

    if (page === 'home') {
        activeDate = parts[1] || activeDate || allQuizzes[0]?.date;
        renderHomeUI();
    } else if (page === 'calendar') {
        renderCalendarUI();
    } else if (page === 'quiz' && parts[1] && parts[2]) {
        startQuizSession(parts[1], parts[2], 0);
    } else if (page === 'results') {
        if (!currentQuiz) navigateTo('home');
        else renderResultsUI();
    } else {
        navigateTo('home');
    }
    window.scrollTo(0,0);
}

function navigateTo(target) { window.location.hash = target; }

async function fetchQuizData() {
    const response = await fetch(`${CONFIG.sheetUrl}${CONFIG.sheetUrl.includes('?') ? '&' : '?'}t=${Date.now()}`);
    const csvData = await response.text();
    const rawQuestions = parseCSVRobust(csvData); // USE NEW ROBUST PARSER

    const now = new Date(new Date().getTime() + CONFIG.istOffset);
    const todayStr = now.toISOString().split('T')[0];

    const grouped = {};
    rawQuestions.forEach(q => {
        if (!q.date || isNaN(new Date(q.date).getTime())) return;
        const d = q.date.trim();
        if (d <= todayStr) {
            if (!grouped[d]) grouped[d] = { date: d, daily: [], ca: [] };
            if (q.type && q.type.trim() === 'current_affairs') grouped[d].ca.push(q);
            else grouped[d].daily.push(q);
        }
    });
    allQuizzes = Object.values(grouped).sort((a, b) => b.date.localeCompare(a.date));
}

/**
 * Advanced CSV Parser that handles:
 * 1. Commas inside quoted fields
 * 2. Newlines (Multi-line) inside quoted fields (Crucial for Aptitude)
 * 3. Empty fields
 */
function parseCSVRobust(str) {
    const arr = [];
    let quote = false;
    let row = 0, col = 0;
    for (let c = 0; c < str.length; c++) {
        let cc = str[c], nc = str[c+1];
        arr[row] = arr[row] || [];
        arr[row][col] = arr[row][col] || '';
        if (cc == '"' && quote && nc == '"') { arr[row][col] += cc; ++c; continue; }
        if (cc == '"') { quote = !quote; continue; }
        if (cc == ',' && !quote) { ++col; continue; }
        if (cc == '\r' && nc == '\n' && !quote) { ++row; col = 0; ++c; continue; }
        if (cc == '\n' && !quote) { ++row; col = 0; continue; }
        if (cc == '\r' && !quote) { ++row; col = 0; continue; }
        arr[row][col] += cc;
    }

    if (arr.length < 2) return [];

    const headers = arr[0].map(h => h.trim().toLowerCase());
    const result = [];
    for (let i = 1; i < arr.length; i++) {
        if (arr[i].length < 2) continue;
        const obj = {};
        headers.forEach((h, idx) => {
            obj[h] = arr[i][idx] ? arr[i][idx].trim() : "";
        });
        result.push(obj);
    }
    return result;
}

function getAdHtml(slotId) {
    if (!CONFIG.adsense.publisherId || CONFIG.adsense.publisherId.includes('XXXXX')) return '';
    return `<ins class="adsbygoogle" style="display:block" data-ad-client="${CONFIG.adsense.publisherId}" data-ad-slot="${slotId}" data-ad-format="auto" data-full-width-responsive="true"></ins><script>(adsbygoogle = window.adsbygoogle || []).push({});</script>`;
}

function startQuizSession(type, date, index = 0) {
    const dayData = allQuizzes.find(q => q.date === date);
    if (!dayData) { navigateTo('home'); return; }
    const questions = type === 'ca' ? dayData.ca : dayData.daily;
    if (!questions || questions.length === 0) { navigateTo('home'); return; }
    currentQuiz = { date, type, questions: shuffleArray([...questions]) };
    currentQuestionIndex = index;
    score = 0;
    renderQuestionUI();
}

function renderHomeUI() {
    currentQuiz = null;
    const container = document.getElementById('main-content');
    if (allQuizzes.length === 0) return;
    const selectedDay = allQuizzes.find(q => q.date === activeDate) || allQuizzes[0];
    const todayStr = new Date(new Date().getTime() + CONFIG.istOffset).toISOString().split('T')[0];

    const t = {
        daily: currentLang === 'ta' ? 'தினசரி வினாடி வினா' : 'Daily Quiz',
        ca: currentLang === 'ta' ? 'நடப்பு நிகழ்வுகள்' : 'Current Affairs',
        history: currentLang === 'ta' ? 'தேதியைத் தேர்ந்தெடுக்கவும்' : 'Pick a Date to Play',
        viewAll: currentLang === 'ta' ? 'அனைத்தையும் பார்க்க' : 'View All ›',
        start: currentLang === 'ta' ? 'தொடங்கு' : 'Start'
    };

    container.innerHTML = `
        <div class="lang-switch-container">
            <span class="switch-label ${currentLang === 'ta' ? 'active' : ''}">தமிழ்</span>
            <label class="toggle-switch">
                <input type="checkbox" id="lang-checkbox" ${currentLang === 'en' ? 'checked' : ''} onchange="toggleLanguage()">
                <span class="slider"></span>
            </label>
            <span class="switch-label ${currentLang === 'en' ? 'active' : ''}">EN</span>
        </div>
        <div class="premium-header-banner">
            <div class="banner-left-content">
                <div class="banner-branding">
                    <div class="logo-white-box" onclick="navigateTo('home')" style="background: white; padding: 5px; border-radius: 14px; display: flex; align-items: center; justify-content: center; width: 60px; height: 60px; cursor: pointer; box-shadow: 0 4px 10px rgba(0,0,0,0.1);">
                        <img src="logo.png" alt="TNPSC Master Logo" style=" border-radius: 10px; width: 53px; height: 53px; object-fit: contain;">
                    </div>
                    <div class="banner-title-group">
                        <h1 class="banner-main-title">TNPSC Master</h1>
                        <p class="banner-slogan" style="font-weight:600; font-size: 0.85rem; margin-top: 4px;">
                            ${currentLang === 'ta' ? 'தினசரி நடப்பு நிகழ்வுகள் & வினாடி வினா' : 'Daily Current Affairs & Quiz'}
                        </p>
                    </div>
                </div>
            </div>
            <div class="banner-right-badge">
                <div class="badge-card-white">
                    <div class="badge-header-info"><span class="badge-top-title">Official Study App</span></div>
                    <a href="https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book" target="_blank" class="download-app-pill">📥 Download</a>
                </div>
            </div>
        </div>

        <!-- 🚀 QUICK LINKS SECTION -->
        <div class="quick-links" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 10px; margin-bottom: 25px;">
            <button class="secondary-btn" onclick="navigateTo('quiz/daily/' + '${todayStr}')" style="margin:0; font-size: 0.8rem; padding: 12px 5px;">
                📝 ${currentLang === 'ta' ? 'இன்று Quiz' : 'Today Quiz'}
            </button>
            <button class="secondary-btn" onclick="navigateTo('quiz/ca/' + '${todayStr}')" style="margin:0; font-size: 0.8rem; padding: 12px 5px;">
                📰 ${currentLang === 'ta' ? 'இன்று CA' : 'Today CA'}
            </button>
            <button class="secondary-btn" onclick="window.open('https://www.tnpsc.gov.in', '_blank')" style="margin:0; font-size: 0.8rem; padding: 12px 5px;">
                📚 ${currentLang === 'ta' ? 'TNPSC Exams' : 'TNPSC Exams'}
            </button>
            <button class="secondary-btn" onclick="navigateTo('calendar')" style="margin:0; font-size: 0.8rem; padding: 12px 5px;">
                🔥 ${currentLang === 'ta' ? 'இன்றைய TNPSC' : "Today's TNPSC"}
            </button>
        </div>

        <div class="featured-section">
            <h2 class="section-title-new" style="margin-bottom: 15px; font-size: 1.1rem;">
                ${currentLang === 'ta' ? 'இன்றைய முக்கிய வினாடி வினா' : "Today's Highlighted Quizzes"}
            </h2>
            <div class="quiz-row-flex" style="display: flex; gap: 15px; flex-wrap: wrap;">
                ${selectedDay.daily.length > 0 ? `
                <div class="premium-quiz-card" style="flex: 1; min-width: 280px; border-left: 6px solid #1a73e8;" onclick="navigateTo('quiz/daily/' + '${selectedDay.date}')">
                    <div class="quiz-details">
                        <div class="quiz-type-tag"><span>📅</span> ${t.daily}</div>
                        <h2 class="quiz-date-text">${formatDate(selectedDay.date)}</h2>
                        <div class="quiz-meta">${selectedDay.daily.length} Questions</div>
                    </div>
                    <button class="premium-start-btn">${t.start}</button>
                </div>` : ''}

                ${selectedDay.ca.length > 0 ? `
                <div class="premium-quiz-card" style="flex: 1; min-width: 280px; border-left: 6px solid #34a853;" onclick="navigateTo('quiz/ca/' + '${selectedDay.date}')">
                    <div class="quiz-details">
                        <div class="quiz-type-tag" style="color: #34a853;"><span>🔥</span> ${t.ca}</div>
                        <h2 class="quiz-date-text">${formatDate(selectedDay.date)}</h2>
                        <div class="quiz-meta">${selectedDay.ca.length} Questions</div>
                    </div>
                    <button class="premium-start-btn" style="background: #34a853;">${t.start}</button>
                </div>` : ''}
            </div>
        </div>
        <div class="ad-slot banner-ad">${getAdHtml(CONFIG.adsense.bannerSlot)}</div>
        <div class="history-section">
            <div class="history-header"><h2 class="section-title-new">${t.history}</h2><a href="javascript:void(0)" class="view-calendar-link" onclick="navigateTo('calendar')">${t.viewAll}</a></div>
            <div class="date-scroller">
                ${allQuizzes.map(q => {
                    const d = new Date(q.date);
                    return `<div class="date-card ${q.date === selectedDay.date ? 'active' : ''}" onclick="activeDate='${q.date}'; renderHomeUI();"><span class="day-label">${q.date === todayStr ? (currentLang === 'ta' ? 'இன்று' : 'Today') : d.toLocaleDateString('en-US', { weekday: 'short' })}</span><span class="date-label">${d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</span></div>`;
                }).join('')}
            </div>
        </div>

        <!-- 📚 NEW KNOWLEDGE HUB SECTION -->
        <section class="knowledge-hub" style="margin-top: 40px; border-top: 1px solid #eee; padding-top: 30px;">
            <h2 class="section-title-new" style="margin-bottom: 20px; color: #174ea6;">
                ${currentLang === 'ta' ? 'பாடவாரியான வழிகாட்டிகள்' : 'Study Guides & Preparation'}
            </h2>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px;">
                <a href="tnpsc-exams-guide.html" style="text-decoration: none; background: #fff; padding: 15px; border-radius: 12px; border: 1px solid #eee; display: flex; flex-direction: column; gap: 5px;">
                    <span style="font-size: 1.2rem;">🏆</span>
                    <span style="font-weight: 700; color: #333; font-size: 0.9rem;">${currentLang === 'ta' ? 'தேர்வு வழிகாட்டி' : 'Exams Guide'}</span>
                    <span style="font-size: 0.75rem; color: #666;">${currentLang === 'ta' ? 'குரூப் 1, 2, 4 உத்திகள்' : 'Group 1, 2, 4 Strategy'}</span>
                </a>
                <a href="tnpsc-group-4-mock-test.html" style="text-decoration: none; background: #fff; padding: 15px; border-radius: 12px; border: 1px solid #eee; display: flex; flex-direction: column; gap: 5px;">
                    <span style="font-size: 1.2rem;">📝</span>
                    <span style="font-weight: 700; color: #333; font-size: 0.9rem;">${currentLang === 'ta' ? 'குரூப் 4 தேர்வு' : 'Group 4 Test'}</span>
                    <span style="font-size: 0.75rem; color: #666;">${currentLang === 'ta' ? 'இலவச மாதிரி தேர்வுகள்' : 'Free Mock Exams'}</span>
                </a>
                <a href="tnpsc-current-affairs.html" style="text-decoration: none; background: #fff; padding: 15px; border-radius: 12px; border: 1px solid #eee; display: flex; flex-direction: column; gap: 5px;">
                    <span style="font-size: 1.2rem;">🔥</span>
                    <span style="font-weight: 700; color: #333; font-size: 0.9rem;">${currentLang === 'ta' ? 'நடப்பு நிகழ்வுகள்' : 'Current Affairs'}</span>
                    <span style="font-size: 0.75rem; color: #666;">${currentLang === 'ta' ? 'முக்கிய செய்திகள்' : 'Latest TN News'}</span>
                </a>
                <a href="https://www.tnpsc.gov.in/english/Syllabus.html" target="_blank" style="text-decoration: none; background: #fff; padding: 15px; border-radius: 12px; border: 1px solid #eee; display: flex; flex-direction: column; gap: 5px;">
                    <span style="font-size: 1.2rem;">📖</span>
                    <span style="font-weight: 700; color: #333; font-size: 0.9rem;">${currentLang === 'ta' ? 'பாடத்திட்டம்' : 'Syllabus'}</span>
                    <span style="font-size: 0.75rem; color: #666;">${currentLang === 'ta' ? 'தேர்வு பாடத்திட்டம்' : 'Latest Syllabus'}</span>
                </a>
            </div>

            <!-- ℹ️ TNPSC INFO SECTION -->
            <div style="margin-top: 30px; background: #f1f3f4; padding: 20px; border-radius: 12px;">
                <h3 style="color: #202124; font-size: 1rem; margin-bottom: 10px;">
                    ${currentLang === 'ta' ? 'தேர்வு பற்றிய தகவல்கள்' : 'About TNPSC Exams'}
                </h3>
                <p style="font-size: 0.85rem; color: #5f6368; line-height: 1.6;">
                    ${currentLang === 'ta'
                        ? 'TNPSC Master என்பது தமிழ்நாடு அரசுப் பணியாளர் தேர்வாணையத் தேர்வுகளுக்கான உங்களின் சிறந்த வழிகாட்டியாகும். குரூப் 1, குரூப் 2, 2A மற்றும் குரூப் 4 தேர்வுகளுக்கான விரிவான பாடப்பொருள், தினசரி நடப்பு நிகழ்வுகள் மற்றும் மாதிரித் தேர்வுகளை நாங்கள் வழங்குகிறோம். சமீபத்திய தேர்வு முறைகளுடன் உங்களைப் புதுப்பித்துக் கொள்ளுங்கள் மற்றும் எங்கள் நிபுணர்களால் தொகுக்கப்பட்ட வினாடி வினாக்கள் மூலம் உங்கள் மதிப்பெண்களை மேம்படுத்துங்கள்.'
                        : 'TNPSC Master is your ultimate guide for Tamil Nadu Public Service Commission exams. We offer comprehensive study materials, daily current affairs, and mock tests for Group 1, Group 2, 2A, and Group 4 exams. Stay updated with the latest exam patterns and improve your scores with our expert-curated quizzes.'}
                </p>
                <ul style="margin-top: 15px; padding-left: 20px; font-size: 0.8rem; color: #3c4043;">
                    <li>${currentLang === 'ta' ? 'தினசரி நடப்பு நிகழ்வுகள்' : 'Daily Current Affairs Updates'}</li>
                    <li>${currentLang === 'ta' ? 'முந்தைய ஆண்டு வினாத்தாள்கள்' : 'Previous Year Question Papers'}</li>
                    <li>${currentLang === 'ta' ? 'பாடவாரியான மாதிரித் தேர்வுகள்' : 'Subject-wise Mock Tests'}</li>
                    <li>${currentLang === 'ta' ? 'குரூப் 4 பொதுத் தமிழ் குறிப்புகள்' : 'Group 4 General Tamil Notes'}</li>
                </ul>
            </div>

            <!-- 🏆 REAL LEADERBOARD SECTION -->
            <div style="margin-top: 40px; border-top: 1px solid #eee; padding-top: 30px;">
                <h2 class="section-title-new" style="margin-bottom: 20px; color: #174ea6;">
                    ${currentLang === 'ta' ? 'சிறந்த வெற்றியாளர்கள்' : 'Top Performers (Leaderboard)'}
                </h2>
                <div style="background: #fff; border-radius: 12px; border: 1px solid #eee; padding: 15px;">
                    ${realLeaderboard.length > 0 ? realLeaderboard.map((user, index) => `
                        <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px 0; border-bottom: ${index < realLeaderboard.length - 1 ? '1px solid #f8f9fa' : 'none'};">
                            <span style="font-weight: 600; font-size: 0.9rem;">
                                ${index === 0 ? '🥇' : index === 1 ? '🥈' : '🥉'} ${user.userName || (currentLang === 'ta' ? 'மாணவர்' : 'Student')}
                            </span>
                            <span style="color: #1a73e8; font-weight: 700;">${user.score} Points</span>
                        </div>
                    `).join('') : `
                        <div style="text-align: center; color: #999; font-size: 0.8rem; padding: 10px;">
                            ${currentLang === 'ta' ? 'இன்றைய தரவரிசை இன்னும் புதுப்பிக்கப்படவில்லை' : 'Today\'s ranks not updated yet'}
                        </div>
                    `}
                    <div style="margin-top: 15px; text-align: center;">
                        <a href="https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book" target="_blank" style="font-size: 0.8rem; color: #5f6368; text-decoration: none;">
                            ${currentLang === 'ta' ? 'முழு தரவரிசையை அறிய ஆப்-ஐ டவுன்லோட் செய்யவும்' : 'Download app to view full leaderboard'}
                        </a>
                    </div>
                </div>
            </div>

            <!-- 📅 REAL NOTIFICATIONS SECTION -->
            <div style="margin-top: 40px; margin-bottom: 20px;">
                <h2 class="section-title-new" style="margin-bottom: 20px; color: #d93025;">
                    ${currentLang === 'ta' ? 'சமீபத்திய தேர்வு அறிவிப்புகள்' : 'Latest TNPSC Notifications'}
                </h2>
                ${latestNotification ? `
                    <div class="notification-card" style="background: #fdf7f7; border-left: 5px solid #d93025; padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                        <h4 style="margin: 0 0 5px 0; font-size: 0.9rem; color: #202124;">${currentLang === 'ta' ? latestNotification.titleTa : latestNotification.titleEn}</h4>
                        <p style="margin: 0; font-size: 0.75rem; color: #5f6368;">📅 ${formatDate(latestNotification.date)} | ${latestNotification.category || ''}</p>
                        <a href="https://www.tnpsc.gov.in" target="_blank" style="display: inline-block; margin-top: 10px; font-size: 0.8rem; color: #d93025; font-weight: 600; text-decoration: none;">${currentLang === 'ta' ? 'அதிகாரப்பூர்வ தளம் →' : 'View Official Site →'}</a>
                    </div>
                ` : `
                    <div class="notification-card" style="background: #fdf7f7; border-left: 5px solid #d93025; padding: 15px; border-radius: 8px; margin-bottom: 15px;">
                        <h4 style="margin: 0 0 5px 0; font-size: 0.9rem; color: #202124;">Combined Technical Services Examination</h4>
                        <p style="margin: 0; font-size: 0.75rem; color: #5f6368;">📅 September 2026 | Last Date: 06 Oct 2026</p>
                        <a href="https://www.tnpsc.gov.in" target="_blank" style="display: inline-block; margin-top: 10px; font-size: 0.8rem; color: #d93025; font-weight: 600; text-decoration: none;">View Official Site →</a>
                    </div>
                `}
            </div>
        </section>
    `;
}

function renderCalendarUI() {
    const container = document.getElementById('main-content');
    container.innerHTML = `
        <div class="calendar-view-container">
            <div class="calendar-header"><button class="back-mini-btn" onclick="history.back()">← Back</button><h2 class="section-title-new">Quiz History</h2></div>
            <div class="calendar-grid">
                ${allQuizzes.map(q => {
                    const d = new Date(q.date);
                    return `<div class="calendar-item" onclick="activeDate='${q.date}'; navigateTo('home')"><span class="cal-month">${d.toLocaleDateString('en-US', { month: 'short' })}</span><span class="cal-day">${d.getDate()}</span></div>`;
                }).join('')}
            </div>
        </div>
    `;
}

function renderQuestionUI() {
    const q = currentQuiz.questions[currentQuestionIndex];
    const container = document.getElementById('main-content');
    const questionText = currentLang === 'ta' ? (q.q_ta || q.question) : (q.q_en || q.question);
    const optA = currentLang === 'ta' ? (q.a_ta || q.optiona) : (q.a_en || q.optiona);
    const optB = currentLang === 'ta' ? (q.b_ta || q.optionb) : (q.b_en || q.optionb);
    const optC = currentLang === 'ta' ? (q.c_ta || q.optionc) : (q.c_en || q.optionc);
    const optD = currentLang === 'ta' ? (q.d_ta || q.optiond) : (q.d_en || q.optiond);
    const expText = currentLang === 'ta' ? (q.exp_ta || q.explanation) : (q.exp_en || q.explanation);

    container.innerHTML = `
        <div class="quiz-container">
            <div class="progress-bar"><div class="progress" style="width: ${((currentQuestionIndex + 1) / currentQuiz.questions.length) * 100}%"></div></div>
            <div class="quiz-header"><button class="back-mini-btn" onclick="history.back()">${currentLang === 'ta' ? '← வெளியேறு' : '← Exit'}</button><span class="score-display">${currentLang === 'ta' ? 'கேள்வி' : 'Q'}: ${currentQuestionIndex + 1}/${currentQuiz.questions.length} | ${currentLang === 'ta' ? 'மதிப்பெண்' : 'Score'}: ${score}</span></div>
            <div class="question-card">
                <div class="difficulty-tag" style="font-size: 0.7rem; color: #1e8e3e; font-weight: 700; text-transform: uppercase; margin-bottom: 8px;">Difficulty: ${q.difficulty || 'Normal'}</div>
                <p class="question-text">${questionText}</p>
                <div class="options-grid">
                    <button class="option-btn" onclick="checkAnswer(0)">${optA}</button>
                    <button class="option-btn" onclick="checkAnswer(1)">${optB}</button>
                    <button class="option-btn" onclick="checkAnswer(2)">${optC}</button>
                    <button class="option-btn" onclick="checkAnswer(3)">${optD}</button>
                </div>
            </div>
            <div id="explanation-box" style="display: none; margin-top: 24px; padding: 20px; background: #f8f9fa; border-radius: 12px; border-left: 5px solid #1a73e8;">
                <h4 style="color: #1a73e8; margin-bottom: 8px;">${currentLang === 'ta' ? 'விளக்கம்' : 'Explanation'}:</h4>
                <p style="font-size: 0.95rem; color: #5f6368; line-height: 1.6;">${expText || '...'}</p>
                <div style="margin-top: 15px; font-size: 0.85rem; color: #174ea6; font-weight: 600; font-style: italic;">💡 TNPSC Tip: ${q.tip || '...'}</div>
                <button class="premium-start-btn" onclick="nextQuestionAfterRead()" style="margin-top: 20px; width: 100%; justify-content: center;">${currentLang === 'ta' ? 'அடுத்த கேள்வி ›' : 'Next Question ›'}</button>
            </div>
            <div class="ad-slot inline-ad">${getAdHtml(CONFIG.adsense.inlineSlot)}</div>
        </div>
    `;
}

function checkAnswer(selectedIndex) {
    const question = currentQuiz.questions[currentQuestionIndex];
    const buttons = document.querySelectorAll('.option-btn');
    const correctIndex = parseInt(question.answer);
    buttons.forEach((btn, idx) => {
        btn.disabled = true;
        if (idx === correctIndex) btn.classList.add('correct');
        else if (idx === selectedIndex) btn.classList.add('wrong');
    });
    if (selectedIndex === correctIndex) score++;
    const expBox = document.getElementById('explanation-box');
    if (expBox) { expBox.style.display = 'block'; window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' }); }
}

function nextQuestionAfterRead() {
    if (currentQuestionIndex + 1 < currentQuiz.questions.length) { currentQuestionIndex++; renderQuestionUI(); }
    else navigateTo('results');
}

function renderResultsUI() {
    const container = document.getElementById('main-content');
    const total = currentQuiz.questions.length;
    const percentage = Math.round((score / total) * 100);

    let msg = "";
    let emoji = "";
    if (percentage >= 80) {
        msg = currentLang === 'ta' ? "மிக நன்று!" : "Excellent!";
        emoji = "🏆";
    } else if (percentage >= 50) {
        msg = currentLang === 'ta' ? "நல்ல முயற்சி!" : "Good Try!";
        emoji = "👍";
    } else {
        msg = currentLang === 'ta' ? "மீண்டும் முயற்சி செய்!" : "Keep Practicing!";
        emoji = "📚";
    }

    container.innerHTML = `
        <div class="result-card">
            <div class="performance-msg">${emoji} ${msg}</div>

            <div class="score-circle">
                <span class="score-num">${score}/${total}</span>
                <span class="score-percent-label">${percentage}% Score</span>
            </div>

            <div class="stats-grid">
                <div class="stat-box success-stat">
                    <span class="stat-val">${score}</span>
                    <span class="stat-label">${currentLang === 'ta' ? 'சரி' : 'Correct'}</span>
                </div>
                <div class="stat-box danger-stat">
                    <span class="stat-val">${total - score}</span>
                    <span class="stat-label">${currentLang === 'ta' ? 'தவறு' : 'Wrong'}</span>
                </div>
            </div>

            <div class="action-buttons">
                <button class="share-btn" onclick="shareResult()">
                    <span>📲</span> ${currentLang === 'ta' ? 'வாட்ஸ்அப்பில் பகிர்க' : 'Share on WhatsApp'}
                </button>
                <button class="secondary-btn" onclick="location.reload()">
                    ${currentLang === 'ta' ? 'மீண்டும் விளையாடு' : 'Try Again'}
                </button>
                <button class="secondary-btn" onclick="navigateTo('home')">
                    ${currentLang === 'ta' ? 'முகப்புப் பக்கம்' : 'Back to Home'}
                </button>
            </div>

            <div class="ad-slot large-ad" style="margin-top:30px;">${getAdHtml(CONFIG.adsense.resultSlot)}</div>
        </div>
    `;
}

function shuffleArray(array) {
    for (let i = array.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [array[i], array[j]] = [array[j], array[i]];
    }
    return array;
}

function shareResult() {
    const text = `🎯 *TNPSC Quiz Challenge | My Result* 🔥\n\nI scored *${score}/${currentQuiz.questions.length}* in today's Daily Quiz! 💯\n\nTNPSC Group 1, 2, 4 தேர்வுக்கு தயாராகிறீர்களா? 📚\nஇந்த Quiz-ல் உங்களுடைய அறிவை Test பண்ணிப் பாருங்கள்!\n\n✅ Daily TNPSC Quiz\n✅ Mock Tests\n✅ Leaderboard & Streak 🔥\n\n📲 *Download App:*\nhttps://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book\n\n👉 *Play Online:*\nhttps://tnpsc-masterapp-dailyquiz.web.app\n\n#TNPSC #TNPSCQuiz #TNPSCGroup4 #TNPSCPreparation #TNPSCMaster #DailyQuiz #Tamilவினாடிவினா`;
    window.open(`https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`);
}

function formatDate(dateStr) {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return "";
    return d.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });
}
function showLoading(show) { document.getElementById('loader').style.display = show ? 'flex' : 'none'; }
function showError(msg) { document.getElementById('main-content').innerHTML = `<div class="error-msg">${msg}</div>`; }
