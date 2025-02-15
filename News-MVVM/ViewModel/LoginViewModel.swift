//
//  LoginViewModel.swift
//  News-MVVM
//
//  Created by Mohamed Shaat on 7/28/19.
//  Copyright © 2019 shaat. All rights reserved.
//

import RxSwift
import LocalizableLib

class LoginViewModel: ViewModelProtocol {
    
    struct Input {
        let userName: AnyObserver<String>
        let password: AnyObserver<String>
        let signInDidTap: AnyObserver<Void>
    }
    
    struct Output {
        let rx_isLoading: Observable<Bool>
        let loginResultObservable: Observable<User>
        let serverErrorsObservable: Observable<String>
        let validationErrorsObservable: Observable<ErrorResponse>
    }
    
    // MARK: - Public properties
    
    let input: Input
    let output: Output
    
    // MARK: - Private properties
    private let rx_isLoadingSubject = PublishSubject<Bool>()
    private let userNameViewModel = UserNameViewModel()
    private let passwordViewModel = PasswordViewModel()
    private let signInDidTapSubject = PublishSubject<Void>()
    private let loginResultSubject = PublishSubject<User>()
    private let serverErrorsSubject = PublishSubject<String>()
    private let validationErrorsSubject = PublishSubject<ErrorResponse>()
    private let disposeBag = DisposeBag()
    
    private var credentialsObservable: Observable<Credentials> {
        return Observable.combineLatest(userNameViewModel.value.asObservable(), passwordViewModel.value.asObservable()) { (userName, password) in
            return Credentials(userName: userName, password: password)
        }
    }
    
    
    init(_ loginService: LoginServiceProtocol) {
        input = Input(userName: userNameViewModel.value.asObserver(),
                      password: passwordViewModel.value.asObserver(),
                      signInDidTap: signInDidTapSubject.asObserver())
        
        output = Output(rx_isLoading: rx_isLoadingSubject.asObservable(), loginResultObservable: loginResultSubject.asObservable(),
                        serverErrorsObservable: serverErrorsSubject.asObservable(), validationErrorsObservable: validationErrorsSubject.asObservable())
        
        signInDidTapSubject.filter{
             return self.validateLoginTextFields()
            }.withLatestFrom(credentialsObservable).do(onNext: { _ in
                 self.rx_isLoadingSubject.onNext(true)
            })
            .flatMapLatest { credentials in
                return loginService.signIn(with: credentials).materialize()
            }.subscribe(onNext: { [weak self] event in
                self?.rx_isLoadingSubject.onNext(false)
                switch event {
                case .next(let user):
                    if user.token != nil {
                     self?.loginResultSubject.onNext(user)
                    } else {
                     self?.serverErrorsSubject.onNext(user.message ?? "")
                    }
                case .error(let error):
                self?.serverErrorsSubject.onNext(error.localizedDescription)
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }
    
    func validateLoginTextFields() -> Bool {
        let error = ErrorResponse(JSON:[:])
        var valid = true
        if !userNameViewModel.validate() {
            valid = false
            error?.name = userNameViewModel.errorMessage
        }
        if !passwordViewModel.validate() {
            valid = false
            error?.password = passwordViewModel.errorMessage
        }
        self.validationErrorsSubject.onNext(error!)
        return valid
    }
    
}
