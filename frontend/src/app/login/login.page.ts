import { Component, OnInit } from '@angular/core';
import { environment } from '../../environments/environment';

@Component({
  selector: 'app-login',
  templateUrl: './login.page.html',
  styleUrls: ['./login.page.scss'],
  standalone: false,
})
export class LoginPage implements OnInit {

  constructor() { }

  ngOnInit() {
  }

  loginWithGoogle() {
    // Redirigir al endpoint de NestJS que inicia el flujo de Google
    window.location.href = `${environment.apiUrl}/auth/google`;
  }

}
