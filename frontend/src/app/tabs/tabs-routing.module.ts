import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';

import { TabsPage } from './tabs.page';

const routes: Routes = [
  {
    path: '',
    component: TabsPage,
    children: [
      {
        path: 'home',
        loadChildren: () => import('../home/home.module').then(m => m.HomePageModule)
      },
      {
        path: 'library',
        loadChildren: () => import('../library/library.module').then(m => m.LibraryPageModule)
      },
      {
        path: 'book-detail',
        loadChildren: () => import('../book-detail/book-detail.module').then(m => m.BookDetailPageModule)
      },
      {
        path: 'callback',
        loadChildren: () => import('../callback/callback.module').then(m => m.CallbackPageModule)
      },
      {
        path: 'profile',
        loadChildren: () => import('../profile/profile.module').then(m => m.ProfilePageModule)
      },
      {
        path: '',
        redirectTo: '/tabs/home',
        pathMatch: 'full'
      }
    ]
  }
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule],
})
export class TabsPageRoutingModule {}
