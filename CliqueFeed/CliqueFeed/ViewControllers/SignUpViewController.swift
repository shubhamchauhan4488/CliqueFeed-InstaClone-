//
//  SignUpViewController.swift
//  CliqueFeed
//
//  Created by SHUBHAM  CHAUHAN on 16/03/18.
//  Copyright © 2018 shubhamchauhan. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseStorage
import FirebaseAuth
import FirebaseCore

class SignUpViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var name: UITextField!
    
    @IBOutlet weak var email: UITextField!
    
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var confirmPassword: UITextField!
    
    @IBOutlet weak var nxtBtn: UIButton!
    let picker = UIImagePickerController()
    var userStorage : StorageReference!
    var databaseRef : DatabaseReference!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        picker.delegate = self
        let storage = Storage.storage().reference(forURL: "gs://cliquefeed-48d9c.appspot.com")
        userStorage = storage.child("users")
        databaseRef = Database.database().reference()
    }

  
    @IBAction func onImageSelect(_ sender: UIButton) {
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        present(picker, animated: true, completion: nil)
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = info[UIImagePickerControllerEditedImage] as? UIImage
        {
        self.profileImage.image = image
        self.nxtBtn.isHidden = false
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onNextPress(_ sender: UIButton) {
        //checking if any field is empty
        guard name.text != "", email.text != "", password.text != "", confirmPassword.text != "" else
        {
            return
        }
        
        //checking if passwords entered match
        if(password.text == confirmPassword.text)
        {
            //Creating user via firebase
            Auth.auth().createUser(withEmail: email.text!, password: password.text!, completion: { (user, error) in
                
                //catching the error
                if let error = error
                {
                    print(error.localizedDescription)
                }
                
                //If user is successfully created on firebase
                if let user = user
                {
//                    let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
//                    changeRequest?.displayName = self.name.text
//                    changeRequest?.commitChanges(completion: nil)
                    
                    let imageRef = self.userStorage.child("\(user.uid).jpg")
                    //Downgrading the image selected by the user and putting in 'data' variable
                    let data = UIImageJPEGRepresentation(self.profileImage.image!, 0.5 )
                    
                    //Putting the image on the 'unique' reference created on Firebase inside Users folder
                    let uploadTask = imageRef.putData(data!, metadata: nil, completion: { (metadata, err) in
                        if let err = err {
                            print(err.localizedDescription)
                        }
                        imageRef.downloadURL(completion: { (url, er) in
                            if let er = er {
                                print(er.localizedDescription)
                            }
                            
                            if let url = url{
                                let userInfo : [String:Any] = ["uid": user.uid,
                                                               "name" : self.name.text!,
                                                               "email" : self.email.text!,
                                                               "password" : self.password.text!,
                                                               "urlImage": url.absoluteString]
                                
                                self.databaseRef.child("users").child(user.uid).setValue(userInfo)
                            }
                            
                            
                        })
                    })
                    uploadTask.resume()
                    
                }
            })
        }
    }
    
}
