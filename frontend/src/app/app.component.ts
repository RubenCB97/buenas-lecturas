import { Component, OnInit } from '@angular/core';
import { AuthService } from './services/auth.service';
import { Router } from '@angular/router';

@Component({
  selector: 'app-root',
  templateUrl: 'app.component.html',
  styleUrls: ['app.component.scss'],
  standalone: false,
})
export class AppComponent implements OnInit {
  constructor(
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit() {
    this.handleOAuthCallbackFallback();
  }

  private handleOAuthCallbackFallback() {
    const currentUrl = new URL(window.location.href);
    const isCallbackPath =
      currentUrl.pathname.endsWith('/callback') ||
      currentUrl.pathname.endsWith('/tabs/callback');
    const isCallbackHash =
      currentUrl.hash.startsWith('#/callback') ||
      currentUrl.hash.startsWith('#/tabs/callback');

    if (!isCallbackPath && !isCallbackHash) return;

    const hashQuery = currentUrl.hash.includes('?') ? currentUrl.hash.split('?')[1] : '';
    const searchQuery = currentUrl.search ? currentUrl.search.substring(1) : '';
    const params = new URLSearchParams(searchQuery || hashQuery);
    const token = params.get('token');
    const userParam = params.get('user');

    if (!token || !userParam) {
      this.router.navigate(['/login']);
      return;
    }

    const user = this.parseUserParam(userParam);
    if (!user) {
      this.router.navigate(['/login']);
      return;
    }

    this.authService.setSession({ access_token: token, user });
  }

  private parseUserParam(userParam: string): any | null {
    try {
      return JSON.parse(userParam);
    } catch (_) {
      try {
        return JSON.parse(decodeURIComponent(userParam));
      } catch (error) {
        console.error('Error parsing callback user payload:', error);
        return null;
      }
    }
  }
}
