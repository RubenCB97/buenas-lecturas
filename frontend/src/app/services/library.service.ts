import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class LibraryService {
  private apiUrl = `${environment.apiUrl}/library`;
  private librarySubject = new BehaviorSubject<any[]>([]);
  library$ = this.librarySubject.asObservable();

  constructor(private http: HttpClient) { 
    this.refreshLibrary().subscribe();
  }

  refreshLibrary(): Observable<any[]> {
    return this.http.get<any[]>(this.apiUrl).pipe(
      tap(books => this.librarySubject.next(books))
    );
  }

  addBook(book: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/add`, { book }).pipe(
      tap(() => this.refreshLibrary().subscribe())
    );
  }

  getLibrary(): Observable<any[]> {
    return this.library$;
  }

  updateStatus(bookId: number, status: string): Observable<any> {
    return this.http.post(`${this.apiUrl}/${bookId}/status`, { status }).pipe(
      tap(() => this.refreshLibrary().subscribe())
    );
  }

  updateRating(bookId: number, rating: number): Observable<any> {
    return this.http.post(`${this.apiUrl}/${bookId}/rating`, { rating }).pipe(
      tap(() => this.refreshLibrary().subscribe())
    );
  }

  getBookById(id: string): Observable<any> {
    return this.http.get(`${this.apiUrl}/${id}`);
  }

  removeBook(bookId: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${bookId}`).pipe(
      tap(() => this.refreshLibrary().subscribe())
    );
  }

  getActivities(): Observable<any[]> {
    return this.http.get<any[]>(`${this.apiUrl}/activities`);
  }
}
