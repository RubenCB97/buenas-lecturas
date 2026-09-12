import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-callback',
  templateUrl: './callback.page.html',
  styleUrls: ['./callback.page.scss'],
  standalone: false,
})
export class CallbackPage implements OnInit {

  constructor(
    private route: ActivatedRoute,
    private authService: AuthService,
    private router: Router
  ) { }

  ngOnInit() {
    this.route.queryParams.subscribe(params => {
      console.log('Callback received params:', params);
      const token = params['token'];
      const userStr = params['user'];

      if (token && userStr) {
        const user = this.parseUserParam(userStr);
        if (user) {
          console.log('Setting session with user:', user);
          this.authService.setSession({ access_token: token, user });
        } else {
          console.error('Error parsing user data');
          this.router.navigate(['/login']);
        }
      } else {
        console.warn('Callback page hit without token/user. Redirecting to login.');
        this.router.navigate(['/login']);
      }
    });
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
