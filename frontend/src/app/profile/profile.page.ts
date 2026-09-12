import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { UserService } from '../services/user.service';
import { LibraryService } from '../services/library.service';

@Component({
  selector: 'app-profile',
  templateUrl: './profile.page.html',
  styleUrls: ['./profile.page.scss'],
  standalone: false,
})
export class ProfilePage implements OnInit {
  user: any = {};
  bookCount: number = 0;
  isEditing: boolean = false;
  myBooks: any[] = [];
  activeTab: string = 'about';
  favoriteGenres: string[] = [];
  activities: any[] = [];

  constructor(
    private userService: UserService,
    private libraryService: LibraryService,
    private router: Router
  ) {}

  ngOnInit() {
    this.loadProfile();
    this.libraryService.getLibrary().subscribe(books => {
      this.myBooks = books;
      this.bookCount = books.length;
      this.extractGenres(books);
    });
    this.libraryService.getActivities().subscribe(activities => {
      this.activities = activities;
    });
  }

  extractGenres(books: any[]) {
    const genres = new Set<string>();
    books.forEach(b => {
      if (b.book?.categories) {
        b.book.categories.forEach((cat: string) => genres.add(cat));
      }
    });
    this.favoriteGenres = Array.from(genres);
  }

  openDetail(book: any) {
    this.router.navigate(['/tabs/book-detail'], { state: { book } });
  }

  loadProfile() {
    this.userService.getProfile().subscribe(user => {
      this.user = user;
    });
  }

  saveProfile() {
    this.userService.updateProfile(this.user).subscribe(() => {
      this.isEditing = false;
    });
  }
}
