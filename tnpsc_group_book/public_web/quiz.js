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
    }
};

let allQuizzes = [];
let currentQuiz = null;
let currentQuestionIndex = 0;
let score = 0;
let activeDate = null;
let currentLang = 'ta';

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
        await fetchQuizData();
        if (allQuizzes.length === 0) {
            showError("No data found.");
            return;
        }
        if (!window.location.hash) window.location.hash = 'home';
        else handleRouting();
    } catch (error) {
        showError("Data Error. Please refresh.");
    } finally {
        showLoading(false);
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
    for (let row = col = c = 0; c < str.length; c++) {
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
                    <div class="banner-title-group"><h1 class="banner-main-title">TNPSC Master</h1><p class="banner-slogan">Learn &nbsp;•&nbsp; Practice &nbsp;•&nbsp; Succeed</p></div>
                </div>
            </div>
            <div class="banner-right-badge">
                <div class="badge-card-white">
                    <div class="badge-header-info"><span class="badge-top-title">Official Study App</span></div>
                    <a href="https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book" target="_blank" class="download-app-pill">📥 Download</a>
                </div>
            </div>
        </div>
        <div class="featured-section">
            <div class="quiz-row-flex" style="display: flex; gap: 15px; flex-wrap: wrap;">
                ${selectedDay.daily.length > 0 ? `<div class="premium-quiz-card" style="flex: 1; min-width: 280px;" onclick="navigateTo('quiz/daily/' + '${selectedDay.date}')"><div class="quiz-details"><div class="quiz-type-tag">📅 ${t.daily}</div><h2 class="quiz-date-text">${formatDate(selectedDay.date)}</h2><div class="quiz-meta">${selectedDay.daily.length} Questions</div></div><button class="premium-start-btn">${t.start}</button></div>` : ''}
                ${selectedDay.ca.length > 0 ? `<div class="premium-quiz-card" style="flex: 1; min-width: 280px; border-left: 6px solid #34a853;" onclick="navigateTo('quiz/ca/' + '${selectedDay.date}')"><div class="quiz-details"><div class="quiz-type-tag" style="color: #34a853;">🔥 ${t.ca}</div><h2 class="quiz-date-text">${formatDate(selectedDay.date)}</h2><div class="quiz-meta">${selectedDay.ca.length} Questions</div></div><button class="premium-start-btn" style="background: #34a853;">${t.start}</button></div>` : ''}
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
