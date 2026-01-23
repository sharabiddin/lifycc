// API implementation with backend support
class API {
    constructor() {
        this.baseUrl = window.location.origin;
        this.apiUrl = '/api';
        // Fallback to mock if API is not available
        this.useMock = true; // Start with mock, will switch when backend is ready
        this.urls = JSON.parse(localStorage.getItem('shortUrls') || '{}');
    }
    
    generateCode() {
        const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let code = '';
        for (let i = 0; i < 6; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return code;
    }
    
    async shorten(url) {
        if (this.useMock) {
            // Mock implementation for now
            await new Promise(resolve => setTimeout(resolve, 800));
            
            const code = this.generateCode();
            const now = new Date();
            const expirationDate = new Date(now);
            expirationDate.setFullYear(expirationDate.getFullYear() + 1);
            
            const urlData = {
                code,
                shortUrl: `${this.baseUrl}/s/${code}`,
                original: url,
                clickCount: 0,
                expirationDate: expirationDate.toISOString(),
                createdAt: now.toISOString()
            };
            
            this.urls[code] = urlData;
            localStorage.setItem('shortUrls', JSON.stringify(this.urls));
            
            return urlData;
        }
        
        // Real API call when backend is ready
        try {
            const response = await fetch(`${this.apiUrl}/shorten`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url })
            });
            
            if (!response.ok) throw new Error('Failed to shorten URL');
            
            const data = await response.json();
            return {
                code: data.code,
                shortUrl: `${this.baseUrl}/s/${data.code}`,
                original: url,
                clickCount: data.clicks || 0,
                createdAt: data.createdAt
            };
        } catch (error) {
            console.error('API error, falling back to mock:', error);
            this.useMock = true;
            return this.shorten(url);
        }
    }
    
    async getStats(code) {
        // Simulate API delay
        await new Promise(resolve => setTimeout(resolve, 300));
        
        const urlData = this.urls[code];
        if (!urlData) {
            throw new Error('URL not found');
        }
        
        // Simulate click count increment
        urlData.clickCount = Math.floor(Math.random() * 100) + 1;
        
        return urlData;
    }
    
    getRecentUrls() {
        return Object.values(this.urls)
            .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
            .slice(0, 10); // Show up to 10 recent URLs
    }
    
    deleteUrl(code) {
        if (this.urls[code]) {
            delete this.urls[code];
            localStorage.setItem('shortUrls', JSON.stringify(this.urls));
            return true;
        }
        return false;
    }
}

// Initialize API
const api = new API();

// DOM Elements
const elements = {
    form: document.getElementById('shortenForm'),
    urlInput: document.getElementById('urlInput'),
    shortenBtn: document.getElementById('shortenBtn'),
    inputSection: document.getElementById('inputSection'),
    successSection: document.getElementById('successSection'),
    loadingSection: document.getElementById('loadingSection'),
    shortUrlDisplay: document.getElementById('shortUrlDisplay'),
    originalUrlDisplay: document.getElementById('originalUrlDisplay'),
    copyBtn: document.getElementById('copyBtn'),
    statsBtn: document.getElementById('statsBtn'),
    newUrlBtn: document.getElementById('newUrlBtn'),
    darkModeToggle: document.getElementById('darkModeToggle'),
    historyBtn: document.getElementById('historyBtn'),
    recentSection: document.getElementById('recentSection'),
    recentList: document.getElementById('recentList'),
    statsModal: document.getElementById('statsModal'),
    closeStatsBtn: document.getElementById('closeStatsBtn'),
    statsContent: document.getElementById('statsContent'),
    toast: document.getElementById('toast'),
    toastMessage: document.getElementById('toastMessage'),
    downloadQRBtn: document.getElementById('downloadQRBtn')
};

// Current shortened URL data
let currentUrlData = null;

// Dark mode initialization
function initDarkMode() {
    const isDarkMode = localStorage.getItem('darkMode') === 'true';
    if (isDarkMode) {
        document.documentElement.classList.add('dark');
    }
}

// Toggle dark mode
elements.darkModeToggle.addEventListener('click', () => {
    document.documentElement.classList.toggle('dark');
    const isDarkMode = document.documentElement.classList.contains('dark');
    localStorage.setItem('darkMode', isDarkMode);
});

// Show toast notification
function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    const toastHtml = `
        <div class="glass dark:glass-dark rounded-lg px-6 py-3 flex items-center space-x-3 toast">
            ${type === 'success' ? 
                `<svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                </svg>` :
                `<svg class="w-5 h-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>`
            }
            <span class="text-gray-900 dark:text-white font-medium">${message}</span>
        </div>
    `;
    
    toast.innerHTML = toastHtml;
    toast.classList.remove('hidden');
    
    // Add slide out animation after delay
    setTimeout(() => {
        toast.firstElementChild.style.animation = 'slideOut 0.3s ease-in forwards';
        setTimeout(() => {
            toast.classList.add('hidden');
        }, 300);
    }, 3000);
}

// Show/hide sections
function showSection(section) {
    const sections = [elements.inputSection, elements.successSection, elements.loadingSection];
    sections.forEach(s => s.classList.add('hidden'));
    section.classList.remove('hidden');
}

// Handle form submission
elements.form.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    let url = elements.urlInput.value.trim();
    if (!url) {
        showToast('Please enter a URL', 'error');
        elements.urlInput.focus();
        return;
    }
    
    // Add protocol if missing
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
        // Check if it looks like a domain (contains a dot)
        if (url.includes('.')) {
            url = 'https://' + url;
            elements.urlInput.value = url;
        } else {
            showToast('Please enter a valid URL (e.g., example.com)', 'error');
            elements.urlInput.focus();
            return;
        }
    }
    
    // Validate the final URL
    try {
        const urlObj = new URL(url);
        // Check if it has a valid hostname
        if (!urlObj.hostname || !urlObj.hostname.includes('.')) {
            throw new Error('Invalid hostname');
        }
    } catch (error) {
        showToast('Please enter a valid URL', 'error');
        elements.urlInput.focus();
        return;
    }
    
    // Show loading state
    showSection(elements.loadingSection);
    
    try {
        // Call mock API with the processed URL
        currentUrlData = await api.shorten(url);
        
        // Display shortened URL
        elements.shortUrlDisplay.value = currentUrlData.shortUrl;
        elements.originalUrlDisplay.textContent = currentUrlData.original;
        
        // Generate QR code
        const qrContainer = document.getElementById('qrcode');
        qrContainer.innerHTML = '';
        
        // Check if QRCode library is loaded
        if (typeof QRCode !== 'undefined') {
            const canvas = document.createElement('canvas');
            QRCode.toCanvas(canvas, currentUrlData.shortUrl, {
                width: 200,
                margin: 2,
                color: {
                    dark: '#1F2937',
                    light: '#FFFFFF'
                }
            }, (error) => {
                if (error) {
                    console.error('QR Code generation error:', error);
                    // Use fallback QR code API
                    generateQRCodeFallback(qrContainer, currentUrlData.shortUrl);
                } else {
                    canvas.className = 'rounded-lg';
                    qrContainer.appendChild(canvas);
                }
            });
        } else {
            console.warn('QRCode library not loaded, using fallback');
            generateQRCodeFallback(qrContainer, currentUrlData.shortUrl);
        }
        
        // Show success section
        showSection(elements.successSection);
        
        // Update recent URLs
        updateRecentUrls();
        
        // Add confetti effect
        createConfetti();
        
        // Show success message
        showToast('URL shortened successfully!', 'success');
        
    } catch (error) {
        console.error('Error shortening URL:', error);
        showToast(error.message || 'Failed to shorten URL. Please try again.', 'error');
        showSection(elements.inputSection);
        elements.urlInput.focus();
    }
});

// Copy to clipboard
elements.copyBtn.addEventListener('click', async () => {
    try {
        await navigator.clipboard.writeText(elements.shortUrlDisplay.value);
        showToast('Copied to clipboard!');
        
        // Animate button
        elements.copyBtn.classList.add('scale-95');
        setTimeout(() => {
            elements.copyBtn.classList.remove('scale-95');
        }, 200);
    } catch (error) {
        showToast('Failed to copy. Please try again.', 'error');
    }
});

// Download QR Code
elements.downloadQRBtn.addEventListener('click', () => {
    if (!currentUrlData) return;
    
    const qrContainer = document.getElementById('qrcode');
    const qrElement = qrContainer.querySelector('canvas, img');
    
    if (!qrElement) {
        showToast('QR code not available', 'error');
        return;
    }
    
    if (qrElement.tagName === 'CANVAS') {
        // Download canvas as image
        qrElement.toBlob((blob) => {
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `${currentUrlData.code}-qr.png`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            showToast('QR code downloaded!');
        });
    } else if (qrElement.tagName === 'IMG') {
        // Download image from API
        fetch(qrElement.src)
            .then(res => res.blob())
            .then(blob => {
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `${currentUrlData.code}-qr.png`;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
                showToast('QR code downloaded!');
            })
            .catch(() => {
                showToast('Failed to download QR code', 'error');
            });
    }
});

// View stats
elements.statsBtn.addEventListener('click', async () => {
    if (!currentUrlData) return;
    
    elements.statsModal.classList.remove('hidden');
    elements.statsContent.innerHTML = `
        <div class="shimmer h-32 rounded-lg"></div>
    `;
    
    try {
        const stats = await api.getStats(currentUrlData.code);
        
        elements.statsContent.innerHTML = `
            <div class="space-y-4">
                <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                    <div class="flex justify-between items-center mb-2">
                        <span class="text-sm text-gray-600 dark:text-gray-400">Short URL</span>
                        <span class="text-sm font-mono text-gray-900 dark:text-white">${stats.shortUrl}</span>
                    </div>
                </div>
                
                <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                    <div class="flex justify-between items-center mb-2">
                        <span class="text-sm text-gray-600 dark:text-gray-400">Total Clicks</span>
                        <span class="text-2xl font-bold gradient-text">${stats.clickCount}</span>
                    </div>
                </div>
                
                <div class="grid grid-cols-2 gap-4">
                    <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                        <span class="text-xs text-gray-600 dark:text-gray-400 block mb-1">Created</span>
                        <span class="text-sm text-gray-900 dark:text-white">${new Date(stats.createdAt).toLocaleDateString()}</span>
                    </div>
                    <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                        <span class="text-xs text-gray-600 dark:text-gray-400 block mb-1">Expires</span>
                        <span class="text-sm text-gray-900 dark:text-white">${new Date(stats.expirationDate).toLocaleDateString()}</span>
                    </div>
                </div>
                
                <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                    <span class="text-xs text-gray-600 dark:text-gray-400 block mb-2">Original URL</span>
                    <span class="text-sm text-gray-900 dark:text-white break-all">${stats.original}</span>
                </div>
            </div>
        `;
    } catch (error) {
        showToast('Failed to load statistics', 'error');
        elements.statsModal.classList.add('hidden');
    }
});

// Close stats modal
elements.closeStatsBtn.addEventListener('click', () => {
    elements.statsModal.classList.add('hidden');
});

elements.statsModal.addEventListener('click', (e) => {
    if (e.target === elements.statsModal) {
        elements.statsModal.classList.add('hidden');
    }
});

// Shorten another URL
elements.newUrlBtn.addEventListener('click', () => {
    elements.urlInput.value = '';
    showSection(elements.inputSection);
    elements.urlInput.focus();
});

// Show/hide history
elements.historyBtn.addEventListener('click', () => {
    elements.recentSection.classList.toggle('hidden');
    updateRecentUrls();
});

// Update recent URLs list
function updateRecentUrls() {
    const recentUrls = api.getRecentUrls();
    
    if (recentUrls.length === 0) {
        elements.recentList.innerHTML = `
            <p class="text-gray-500 dark:text-gray-400 text-center py-8">No recent URLs</p>
        `;
        elements.recentSection.classList.add('hidden');
        return;
    }
    
    // Show the section if there are URLs
    if (recentUrls.length > 0) {
        elements.recentSection.classList.remove('hidden');
    }
    
    elements.recentList.innerHTML = recentUrls.map(url => `
        <div class="glass dark:glass-dark rounded-lg p-4 hover:shadow-md transition-all">
            <div class="flex justify-between items-start">
                <div class="flex-1 mr-4">
                    <div class="flex items-center space-x-2 mb-1">
                        <span class="text-sm font-bold text-purple-600 dark:text-purple-400">${url.code}</span>
                        <span class="text-xs text-gray-500 dark:text-gray-400">•</span>
                        <span class="text-xs text-gray-500 dark:text-gray-400">${new Date(url.createdAt).toLocaleDateString()}</span>
                    </div>
                    <p class="text-xs text-gray-600 dark:text-gray-400 truncate mb-2">${url.original}</p>
                    <div class="flex space-x-2">
                        <button onclick="copyUrl('${url.shortUrl}')" class="text-xs bg-gray-100 dark:bg-gray-700 px-3 py-1 rounded hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors">
                            Copy Link
                        </button>
                        <button onclick="viewUrlStats('${url.code}')" class="text-xs bg-purple-100 dark:bg-purple-900 text-purple-600 dark:text-purple-400 px-3 py-1 rounded hover:bg-purple-200 dark:hover:bg-purple-800 transition-colors">
                            View Stats
                        </button>
                        <button onclick="deleteUrl('${url.code}')" class="text-xs bg-red-100 dark:bg-red-900 text-red-600 dark:text-red-400 px-3 py-1 rounded hover:bg-red-200 dark:hover:bg-red-800 transition-colors">
                            Delete
                        </button>
                    </div>
                </div>
                <div class="text-right">
                    <p class="text-lg font-bold gradient-text">${url.clickCount}</p>
                    <p class="text-xs text-gray-600 dark:text-gray-400">clicks</p>
                </div>
            </div>
        </div>
    `).join('');
}

// Copy URL from history
window.copyUrl = async (url) => {
    try {
        await navigator.clipboard.writeText(url);
        showToast('Copied to clipboard!');
    } catch (error) {
        showToast('Failed to copy. Please try again.', 'error');
    }
};

// View URL stats from history
window.viewUrlStats = async (code) => {
    elements.statsModal.classList.remove('hidden');
    elements.statsContent.innerHTML = `
        <div class="shimmer h-32 rounded-lg"></div>
    `;
    
    try {
        const stats = await api.getStats(code);
        
        elements.statsContent.innerHTML = `
            <div class="space-y-4">
                <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                    <div class="flex justify-between items-center mb-2">
                        <span class="text-sm text-gray-600 dark:text-gray-400">Short URL</span>
                        <span class="text-sm font-mono text-gray-900 dark:text-white">${stats.shortUrl}</span>
                    </div>
                </div>
                
                <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                    <div class="flex justify-between items-center mb-2">
                        <span class="text-sm text-gray-600 dark:text-gray-400">Total Clicks</span>
                        <span class="text-2xl font-bold gradient-text">${stats.clickCount}</span>
                    </div>
                </div>
                
                <div class="grid grid-cols-2 gap-4">
                    <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                        <span class="text-xs text-gray-600 dark:text-gray-400 block mb-1">Created</span>
                        <span class="text-sm text-gray-900 dark:text-white">${new Date(stats.createdAt).toLocaleDateString()}</span>
                    </div>
                    <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                        <span class="text-xs text-gray-600 dark:text-gray-400 block mb-1">Expires</span>
                        <span class="text-sm text-gray-900 dark:text-white">${new Date(stats.expirationDate).toLocaleDateString()}</span>
                    </div>
                </div>
                
                <div class="bg-gray-100 dark:bg-gray-800 rounded-lg p-4">
                    <span class="text-xs text-gray-600 dark:text-gray-400 block mb-2">Original URL</span>
                    <span class="text-sm text-gray-900 dark:text-white break-all">${stats.original}</span>
                </div>
            </div>
        `;
    } catch (error) {
        showToast('Failed to load statistics', 'error');
        elements.statsModal.classList.add('hidden');
    }
};

// Delete URL from history
window.deleteUrl = (code) => {
    if (confirm('Are you sure you want to delete this shortened URL?')) {
        if (api.deleteUrl(code)) {
            showToast('URL deleted successfully');
            updateRecentUrls();
            
            // If this was the current URL, clear the success section
            if (currentUrlData && currentUrlData.code === code) {
                showSection(elements.inputSection);
                currentUrlData = null;
            }
        } else {
            showToast('Failed to delete URL', 'error');
        }
    }
};

// Create confetti effect
function createConfetti() {
    const colors = ['#667EEA', '#764BA2', '#F472B6', '#10B981', '#F59E0B'];
    const confettiCount = 50;
    
    for (let i = 0; i < confettiCount; i++) {
        const confetti = document.createElement('div');
        confetti.style.position = 'fixed';
        confetti.style.width = '10px';
        confetti.style.height = '10px';
        confetti.style.backgroundColor = colors[Math.floor(Math.random() * colors.length)];
        confetti.style.left = Math.random() * 100 + '%';
        confetti.style.top = '-10px';
        confetti.style.opacity = Math.random() + 0.5;
        confetti.style.transform = `rotate(${Math.random() * 360}deg)`;
        confetti.style.pointerEvents = 'none';
        confetti.style.zIndex = '9999';
        
        document.body.appendChild(confetti);
        
        const duration = Math.random() * 2 + 1;
        const distance = Math.random() * 200 + 100;
        
        confetti.animate([
            { transform: `translateY(0) rotate(0deg)`, opacity: 1 },
            { transform: `translateY(${distance}vh) rotate(${Math.random() * 720}deg)`, opacity: 0 }
        ], {
            duration: duration * 1000,
            easing: 'cubic-bezier(0.25, 0.46, 0.45, 0.94)'
        });
        
        setTimeout(() => confetti.remove(), duration * 1000);
    }
}

// Fallback QR code generation using API
function generateQRCodeFallback(container, url) {
    const img = document.createElement('img');
    const encodedUrl = encodeURIComponent(url);
    img.src = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodedUrl}&bgcolor=FFFFFF&color=1F2937`;
    img.alt = 'QR Code';
    img.className = 'rounded-lg';
    img.width = 200;
    img.height = 200;
    container.appendChild(img);
}

// Initialize dark mode on load
initDarkMode();

// Load and display recent URLs on page load
updateRecentUrls();

// Focus on input on load
elements.urlInput.focus();