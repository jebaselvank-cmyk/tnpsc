/**
 * TNPSC Master - Dual Mode Router (Daily + Current Affairs)
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

document.addEventListener('DOMContentLoaded', () => {
    initApp();
    window.addEventListener('hashchange', () => handleRouting());
});

async function initApp() {
    showLoading(true);
    try {
        await fetchQuizData();
        if (allQuizzes.length === 0) {
            showError("No data found. Please check Google Sheet.");
            return;
        }
        // Base state setup
        if (!window.location.hash || window.location.hash === '#home') {
            history.replaceState({page: 'home'}, '', '#home');
        }
        handleRouting();
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
        // Quiz Route: #quiz/type/date
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
    const rawQuestions = parseCSV(csvData);

    const now = new Date(new Date().getTime() + CONFIG.istOffset);
    const todayStr = now.toISOString().split('T')[0];

    const grouped = {};
    rawQuestions.forEach(q => {
        if (!q.date) return;
        const d = q.date.trim();
        if (d <= todayStr) {
            if (!grouped[d]) grouped[d] = { date: d, daily: [], ca: [] };
            if (q.type && q.type.trim() === 'current_affairs') grouped[d].ca.push(q);
            else grouped[d].daily.push(q);
        }
    });
    allQuizzes = Object.values(grouped).sort((a, b) => b.date.localeCompare(a.date));
}

function parseCSV(csv) {
    const lines = csv.split('\n');
    const result = [];
    if (lines.length < 2) return result;
    const headers = lines[0].split(',').map(h => h.trim().replace(/"/g, '').toLowerCase());
    for (let i = 1; i < lines.length; i++) {
        if (!lines[i].trim()) continue;
        const currentLine = lines[i].split(/,(?=(?:(?:[^"]*"){2})*[^"]*$)/);
        const obj = {};
        headers.forEach((header, index) => {
            obj[header] = currentLine[index] ? currentLine[index].trim().replace(/"/g, '') : '';
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

    container.innerHTML = `
        <div class="premium-header-banner">
            <div class="banner-left-content">
                <div class="banner-branding">
                    <img src="logo.png" alt="Logo" class="banner-main-logo" onclick="navigateTo('home')">
                    <div class="banner-title-group"><h1 class="banner-main-title">TNPSC Master</h1><p class="banner-slogan">Learn &nbsp;•&nbsp; Practice &nbsp;•&nbsp; Succeed</p></div>
                </div>
            </div>
            <div class="banner-right-badge">
                <div class="badge-card-white">
                    <div class="badge-header-info"><span class="badge-top-title">TNPSC Master</span><span class="badge-top-sub">Official Study App</span></div>
                    <a href="https://play.google.com/store/apps/details?id=com.tnpsc.groupbook.tnpsc_group_book" target="_blank" class="download-app-pill">📥 Download</a>
                </div>
            </div>
        </div>
        <div class="featured-section">
            <div class="quiz-row-flex" style="display: flex; gap: 15px; flex-wrap: wrap;">
                ${selectedDay.daily.length > 0 ? `<div class="premium-quiz-card" style="flex: 1; min-width: 280px;" onclick="navigateTo('quiz/daily/' + '${selectedDay.date}')"><div class="quiz-details"><div class="quiz-type-tag">📅 Daily Quiz</div><h2 class="quiz-date-text">${formatDate(selectedDay.date)}</h2><div class="quiz-meta">${selectedDay.daily.length} Questions</div></div><button class="premium-start-btn">Start ›</button></div>` : ''}
                ${selectedDay.ca.length > 0 ? `<div class="premium-quiz-card" style="flex: 1; min-width: 280px; border-left: 6px solid #34a853;" onclick="navigateTo('quiz/ca/' + '${selectedDay.date}')"><div class="quiz-details"><div class="quiz-type-tag" style="color: #34a853;">🔥 Current Affairs</div><h2 class="quiz-date-text">${formatDate(selectedDay.date)}</h2><div class="quiz-meta">${selectedDay.ca.length} Questions</div></div><button class="premium-start-btn" style="background: #34a853;">Start ›</button></div>` : ''}
            </div>
        </div>
        <div class="ad-slot banner-ad">${getAdHtml(CONFIG.adsense.bannerSlot)}</div>
        <div class="history-section">
            <div class="history-header"><h2 class="section-title-new">Pick a Date to Play</h2><a href="javascript:void(0)" class="view-calendar-link" onclick="navigateTo('calendar')">View All ›</a></div>
            <div class="date-scroller">
                ${allQuizzes.map(q => `<div class="date-card ${q.date === selectedDay.date ? 'active' : ''}" onclick="activeDate='${q.date}'; renderHomeUI();"><span class="day-label">${q.date === todayStr ? 'Today' : new Date(q.date).toLocaleDateString('en-US', { weekday: 'short' })}</span><span class="date-label">${new Date(q.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</span></div>`).join('')}
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
                ${allQuizzes.map(q => `<div class="calendar-item" onclick="activeDate='${q.date}'; navigateTo('home')"><span class="cal-month">${new Date(q.date).toLocaleDateString('en-US', { month: 'short' })}</span><span class="cal-day">${new Date(q.date).getDate()}</span></div>`).join('')}
            </div>
        </div>
    `;
}

function renderQuestionUI() {
    const q = currentQuiz.questions[currentQuestionIndex];
    const container = document.getElementById('main-content');
    const optA = q.optiona || q.optionA || ""; const optB = q.optionb || q.optionB || ""; const optC = q.optionc || q.optionC || ""; const optD = q.optiond || q.optionD || "";

    container.innerHTML = `
        <div class="quiz-container">
            <div class="progress-bar"><div class="progress" style="width: ${((currentQuestionIndex + 1) / currentQuiz.questions.length) * 100}%"></div></div>
            <div class="quiz-header"><button class="back-mini-btn" onclick="history.back()">← Exit</button><span class="score-display">Q: ${currentQuestionIndex + 1}/${currentQuiz.questions.length} | Score: ${score}</span></div>
            <div class="question-card"><p class="question-text">${q.question}</p><div class="options-grid">
                <button class="option-btn" onclick="checkAnswer(0)">${optA}</button>
                <button class="option-btn" onclick="checkAnswer(1)">${optB}</button>
                <button class="option-btn" onclick="checkAnswer(2)">${optC}</button>
                <button class="option-btn" onclick="checkAnswer(3)">${optD}</button>
            </div></div>
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
    setTimeout(() => {
        if (currentQuestionIndex + 1 < currentQuiz.questions.length) { currentQuestionIndex++; renderQuestionUI(); }
        else navigateTo('results');
    }, 1200);
}

function renderResultsUI() {
    const container = document.getElementById('main-content');
    const percentage = Math.round((score / currentQuiz.questions.length) * 100);
    container.innerHTML = `
        <div class="result-card">
            <h2 class="result-title">Well Done!</h2>
            <div class="score-circle" style="--percentage: ${percentage}%"><div class="score-content"><span class="score-num">${score}/${currentQuiz.questions.length}</span><span class="score-percent">${percentage}% Score</span></div></div>
            <div class="ad-slot large-ad">${getAdHtml(CONFIG.adsense.resultSlot)}</div>
            <button class="share-btn" onclick="shareResult()">Share Score on WhatsApp</button>
            <button class="home-btn" onclick="navigateTo('home')">Back to Home</button>
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
    const text = `📊 *TNPSC Quiz Result*\n\nI scored *${score}/${currentQuiz.questions.length}* in today's Daily Quiz!\n\nTry here: https://tnpsc-masterapp-dailyquiz.web.app`;
    window.open(`https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`);
}

function formatDate(dateStr) { return new Date(dateStr).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }); }
function showLoading(show) { document.getElementById('loader').style.display = show ? 'flex' : 'none'; }
function showError(msg) { document.getElementById('main-content').innerHTML = `<div class="error-msg">${msg}</div>`; }
